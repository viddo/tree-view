path = require 'path'
fs = require 'fs-plus'
{CompositeDisposable, Emitter} = require 'atom'
{repoForPath} = require './helpers'

module.exports =
class File
  constructor: ({@name, fullPath, @symlink, realpathCache, @ignoredNames, useSyncFS, @stats}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    @path = fullPath
    @realPath = @path

    @subscribeToRepo()
    @updateStatus()

    if useSyncFS
      @realPath = fs.realpathSync(@path)
    else
      fs.realpath @path, realpathCache, (error, realPath) =>
        return if @destroyed
        if realPath and realPath isnt @path
          @realPath = realPath
          @updateStatus()

  destroy: ->
    @destroyed = true
    @subscriptions.dispose()
    @emitter.emit('did-destroy')

  onDidDestroy: (callback) ->
    @emitter.on('did-destroy', callback)

  onDidStatusChange: (callback) ->
    @emitter.on('did-status-change', callback)

  # Subscribe to the project's repo for changes to the Git status of this file.
  subscribeToRepo: ->
    repo = repoForPath(@path)
    return unless repo?

    @subscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @isPathEqual(event.path)
    @subscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus: ->
    repo = repoForPath(@path)
    return unless repo?

    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else if @ignoredNames.matches(@path)
      newStatus = 'ignored-name'
    else
      status = repo.getCachedPathStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @emitter.emit('did-status-change', newStatus)

  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare
