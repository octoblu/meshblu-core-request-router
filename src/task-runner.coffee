debug      = require('debug')('meshblu-core-dispatcher:task-runner')

class TaskRunner
  constructor: (options={}, dependencies={}) ->
    {@config,@request,@datastoreFactory,@pepper,@cacheFactory} = options

  @TASKS =
    'meshblu-core-task-black-list-token'      : require('meshblu-core-task-black-list-token')
    'meshblu-core-task-cache-token'           : require('meshblu-core-task-cache-token')
    'meshblu-core-task-check-token'           : require('meshblu-core-task-check-token')
    'meshblu-core-task-check-token-black-list': require('meshblu-core-task-check-token-black-list')
    'meshblu-core-task-check-token-cache'     : require('meshblu-core-task-check-token-cache')
    'meshblu-core-task-no-content'            : require('meshblu-core-task-no-content')

  run: (callback) =>
    @_doTask @config.start, callback

  _doTask: (name, callback) =>
    taskConfig = @config.tasks[name]
    return callback new Error "Task Definition '#{name}' not found" unless taskConfig?

    taskName = taskConfig.task
    Task = TaskRunner.TASKS[taskName]
    return callback new Error "Task Definition '#{name}' missing task class" unless Task?

    debug '_doTask', taskName

    datastore = @datastoreFactory.build taskConfig.datastoreCollection if taskConfig.datastoreCollection?
    cache  = @cacheFactory.build taskConfig.cacheNamespace if taskConfig.cacheNamespace?
    task = new Task
      datastore: datastore
      cache: cache
      pepper: @pepper

    task.do @request, (error, response) =>
      return callback error if error?
      debug taskName, response
      {metadata,rawData} = response

      codeStr = metadata?.code?.toString()
      nextTask = taskConfig.on?[codeStr]
      return callback null, response unless nextTask?
      @_doTask nextTask, callback

module.exports = TaskRunner