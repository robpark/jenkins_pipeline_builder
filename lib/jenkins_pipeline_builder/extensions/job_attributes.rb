#
# Copyright (c) 2014 Constant Contact
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

job_attribute do
  name :description
  plugin_id 'builtin'
  description 'This is the description of your job.'
  jenkins_name 'Description'
  announced false

  before do
    xpath('//project/description').remove
  end

  xml path: '//project' do |description|
    description "#{description}"
  end
end

job_attribute do
  name :scm_params
  plugin_id 'git'
  description 'NOTE: This only supports git currently, the following is the description for the git plugin.
  This plugin allows use of Git as a build SCM. A recent Git runtime is required (1.7.9 minimum, 1.8.x recommended). Plugin is only tested on official git client. Use exotic installations at your own risks.'
  jenkins_name "Git (inside 'Source Code Management')"
  announced false

  # XML preprocessing
  # TODO: Actually figure out how to merge using the builder DSL
  # This delete the things we are going to add later is pretty crappy
  # Alternately don't use/tweak the xml the api client generates
  # (which is where I assume this is coming from)
  before do |params|
    xpath('//scm/localBranch').remove if params[:local_branch]
    xpath('//scm/recursiveSubmodules').remove if params[:recursive_update]
    xpath('//scm/wipeOutWorkspace').remove if params[:wipe_workspace]
    xpath('//scm/excludedUsers').remove if params[:excluded_users]
    xpath('//scm/userRemoteConfigs').remove if params[:remote_name] || params[:refspec]
    xpath('//scm/skipTag').remove if params[:skip_tag]
    xpath('//scm/excludedRegions').remove if params[:excluded_regions]
    xpath('//scm/includedRegions').remove if params[:included_regions]

  end

  xml path: '//scm' do |params|
    localBranch params[:local_branch] if params[:local_branch]
    recursiveSubmodules params[:recursive_update] if params[:recursive_update]
    wipeOutWorkspace params[:wipe_workspace] if params[:wipe_workspace]
    excludedUsers params[:excluded_users] if params[:excluded_users]
    if params[:remote_name]
      userRemoteConfigs do
        send('hudson.plugins.git.UserRemoteConfig') do
          name params[:remote_name]
        end
      end
    end
    skipTag params[:skip_tag] if params[:skip_tag]
    if params[:refspec]
      userRemoteConfigs do
        send 'hudson.plugins.git.UserRemoteConfig' do
          refspec params[:refspec]
        end
      end
    end
    excludedRegions params[:excluded_regions] if params[:excluded_regions]
    includedRegions params[:included_regions] if params[:included_regions]
  end
end

job_attribute do
  name :hipchat
  plugin_id 'hipchat'
  description 'This plugin allows your team to setup build notifications to be sent to HipChat rooms.'
  jenkins_name 'HipChat Notifications'
  announced false

  xml path: '//properties' do |params|
    fail 'No HipChat room specified' unless params[:room]

    send('jenkins.plugins.hipchat.HipChatNotifier_-HipChatJobProperty') do
      room params[:room]
      startNotification params[:'start-notify'] || false
    end
  end
end

job_attribute do
  name :priority
  plugin_id 'PrioritySorter'
  description 'This plugin adds the ability to assign different priorities to Jobs, the lower priority the job has the sooner the Job will run.'
  jenkins_name 'Use specific priority for this Job'
  announced false

  xml path: '//properties' do |params|
    send('jenkins.advancedqueue.AdvancedQueueSorterJobProperty', 'plugin' => 'PrioritySorter') do
      useJobPriority params[:use_priority]
      priority params[:job_priority] || -1
    end
  end
end

job_attribute do
  name :parameters
  plugin_id 'builtin'
  description 'Allows the job to take parameters.'
  jenkins_name 'This build is parameterized'
  announced false

  xml path: '//properties' do |params|
    send('hudson.model.ParametersDefinitionProperty') do
      parameterDefinitions do
        params.each do |param|
          case param[:type]
          when 'string'
            paramType = 'hudson.model.StringParameterDefinition'
          when 'bool'
            paramType = 'hudson.model.BooleanParameterDefinition'
          when 'text'
            paramType = 'hudson.model.TextParameterDefinition'
          when 'password'
            paramType = 'hudson.model.PasswordParameterDefinition'
          when 'choice'
            paramType = 'hudson.model.ChoiceParameterDefinition'
          else
            paramType = 'hudson.model.StringParameterDefinition'
          end

          send(paramType) do
            name param[:name]
            description param[:description]
            defaultValue param[:default]
            if param[:type] == 'choice'
              choices('class' => 'java.util.Arrays$ArrayList') do
                a('class' => 'string-array') do
                  param[:values].each do |value|
                    string value
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

job_attribute do
  name :discard_old
  plugin_id 'builtin'
  description 'Allows you to discard old builds.'
  jenkins_name 'Discard Old Builds'
  announced false

  xml path: '//project' do |params|
    send('logRotator', 'class' => 'hudson.tasks.LogRotator') do
      daysToKeep params[:days] if params[:days]
      numToKeep params[:number] || -1
      artifactDaysToKeep params[:artifact_days] || -1
      artifactNumToKeep params[:artifact_number] || -1
    end
  end
end

job_attribute do
  name :throttle
  plugin_id 'throttle-concurrents'
  description 'This plugin allows for throttling the number of concurrent builds of a project running per node or globally.'
  jenkins_name 'Throttle Concurrent Builds'
  announced false

  xml path: '//properties' do |params|
    cat_set = params[:option] == 'category'
    send('hudson.plugins.throttleconcurrents.ThrottleJobProperty', 'plugin' => 'throttle-concurrents') do
      maxConcurrentPerNode params[:max_per_node] || 0
      maxConcurrentTotal params[:max_total] || 0
      throttleEnabled true
      throttleOption params[:option] || 'alone'
      categories do
        string params[:category] if cat_set
      end
    end
  end
end

job_attribute do
  name :prepare_environment
  plugin_id 'envinject'
  description 'This plugin makes it possible to have an isolated environment for your jobs.'
  jenkins_name 'Prepare an environment for the run'
  announced false

  xml path: '//properties' do |params|
    send('EnvInjectJobProperty') do
      info do
        propertiesContent params[:properties_content] if params[:properties_content]
        loadFilesFromMaster params[:load_from_master] if params[:load_from_master]
      end
      on true
      keepJenkinsSystemVariables params[:keep_environment] if params[:keep_environment]
      keepBuildVariables params[:keep_build] if params[:keep_build]
    end
  end
end

job_attribute do
  name :concurrent_build
  plugin_id 'builtin'
  description 'Allows toggling of concurrent builds.'
  jenkins_name 'Execute concurrent builds if necessary'
  announced false

  xml path: '//concurrentBuild' do |params|
    (params == true) ? 'true' : 'false'
  end
end
