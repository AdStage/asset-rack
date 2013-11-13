fs = require 'fs'
pathutil = require 'path'
browserify = require 'browserify'
uglify = require('uglify-js')
Asset = require('../index').Asset
Q = require('q')

class exports.BrowserifyAsset extends Asset
    mimetype: 'text/javascript'

    create: (options) ->
      @filename = options.filename
      @toWatch = options.toWatch or pathutil.dirname pathutil.resolve options.filename
      @require = options.require
      @debug = options.debug or false
      @compress = options.compress
      @external = options.external
      @transform = options.transform
      @prependAsset = options.prepend
      @compress ?= false
      delimiter = '\n;\n'
      @extensionHandlers = options.extensionHandlers or []
      @agent = browserify watch: false, debug: @debug
      for handler in @extensionHandlers
          @agent.register(handler.ext, handler.handler)
      @agent.add @filename if @filename

      if @require
          for r in @require
              if r.file
                  agent.require r.file, r.options
              else
                  agent.require r

      @agent.external ext for ext in @external if @external
      @agent.transform t for t in @transform if @transform

      @agent.transform 'coffeeify' if /.coffee$/.test @filename

      if @prependAsset
        promises = []
        unless @prependAsset instanceof Array
          @prependAsset = [@prependAsset]
        @prependAsset.forEach (asset)=>
          deferred = Q.defer()
          promises.push deferred.promise
          asset.on 'complete', ()->
            deferred.resolve asset.contents
        Q.all(promises).done (contentsArray)=>
          @finish(contentsArray.join(delimiter) + delimiter)
      else
        @finish('')
      
    finish: (prependContents)->
      @agent.bundle {debug: @debug}, (error, src) =>
        # return @emit 'error', error if error?
        uncompressed = prependContents + src;
        if @compress is true
            @contents = uglify.minify(uncompressed, {fromString: true}).code
            @emit 'created'
        else
            @emit 'created', contents: uncompressed

    getInSourceMap: (compiled)->
      SOURCE_MAP_REGEXP = /\/\/(?:@|#)\s*source(?:Mapping)?URL=data:application\/json;base64,(.+)\n/
      tail = (string, lineCount)->
        nextIndex = undefined
        for line in [lineCount..1]
          do ->
            previousIndex = nextIndex
            nextIndex = string.lastIndexOf('\n', previousIndex - 1)
        string.substring(nextIndex)

      return if (typeof compiled) != 'string'

      sourceMap = tail(compiled, 5)
      .match(SOURCE_MAP_REGEXP)

      return if !(sourceMap? && sourceMap[1]?)

      tempfile = '/Users/bwhite/Desktop/temp.map'
      fs.writeFileSync(tempfile, new Buffer(sourceMap[1],
        'base64').toString())

      tempfile

    finish: (prependContents)->
      @agent.bundle
        debug: @debug
        , (err, src)=>
#          return @emit 'error', error if error?
          uncompressed = prependContents + src
          #          uncompressed = src
          if @compress is true
#            @contents = do =>
#              toplevel = uglify.parse uncompressed, 
#                filename: @filename
#              toplevel.figure_out_scope()
##              compressed_ast = toplevel #TEMP!!
#              compressed_ast = toplevel.transform(uglify.Compressor())
#              compressed_ast.figure_out_scope()
#              compressed_ast.compute_char_frequency()
#              compressed_ast.mangle_names()
#              
#              source_map = uglify.SourceMap#()
#                file: @filename,
#                orig: @getInSourceMap(src)
#              
##              compressed_ast.print_to_string
##                source_map: source_map
#            
#              stream = uglify.OutputStream
#                source_map: source_map
#              
#              compressed_ast.print stream
#              
#              code = stream.toString()
            @contents = do =>
              min = uglify.minify(uncompressed,
                fromString: true,
                inSourceMap: @getInSourceMap(src),
                outSourceMap: 'my-min.map'
              )#.code

              min.code + "//# sourceMappingURL=data:;base64,#{new Buffer(min.map).toString('base64')}"
