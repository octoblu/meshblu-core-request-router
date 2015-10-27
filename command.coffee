commander    = require 'commander'
async        = require 'async'
redis        = require 'redis'
redisMock    = require 'fakeredis'
debug        = require('debug')('meshblu-core-dispatcher:command')
packageJSON  = require './package.json'
Dispatcher   = require './src/dispatcher'
JobAssembler = require './src/job-assembler'
QueueWorker  = require './src/queue-worker'

class Command
  parseOptions: =>
    commander
      .version packageJSON.version
      .option '-n, --namespace <meshblu>', 'request/response queue namespace.', 'meshblu'
      .option '-i, --internal-namespace <meshblu:internal>', 'job handler queue namespace.', 'meshblu:internal'
      .option '-s, --single-run', 'perform only one job.'
      .option '-t, --timeout <n>', 'seconds to wait for a next job.', parseInt, 30
      .option '-a, --all', 'run all workers in process'
      .parse process.argv

    {@namespace,@internalNamespace,@singleRun,@timeout,@all} = commander
    @redisUri = process.env.REDIS_URI

    if @all
      @localHandlers  = ['authenticate']
      @remoteHandlers = []
    else
      @localHandlers  = []
      @remoteHandlers = ['authenticate']

  run: =>
    @parseOptions()

    dispatcher = new Dispatcher
      client:  redis.createClient @redisUri
      namespace: @namespace
      timeout:   @timeout
      jobHandlers: @assembleJobHandlers()

    dispatcher.on 'job', (job) =>
      debug 'doing a job: ', JSON.stringify job

    queueWorker = new QueueWorker
      timeout: 30
      namespace: @internalNamespace
      localClient: @localClient
      remoteClient: @remoteClient
      localHandlers: @localHandlers
      remoteHandlers: @remoteHandlers

    return queueWorker.run() if @singleRun
    async.forever queueWorker.run, @panic

    return dispatcher.work(@panic) if @singleRun
    async.forever dispatcher.dispatch, @panic

  assembleJobHandlers: =>
    @localClient = redisMock.createClient()
    @remoteClient = redis.createClient @redisUri

    jobAssembler = new JobAssembler
      timeout: @timeout
      namespace: @internalNamespace
      localClient: @localClient
      remoteClient: @remoteClient
      localHandlers: @localHandlers
      remoteHandlers: @remoteHandlers

    jobAssembler.on 'response', (response) =>
      debug 'response', JSON.stringify response

    jobAssembler.assemble()

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command()
command.run()
