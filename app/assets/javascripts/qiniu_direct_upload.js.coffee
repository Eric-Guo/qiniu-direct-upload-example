#= require jquery-fileupload/basic
#= require jquery-fileupload/vendor/tmpl

$ = jQuery

$.fn.QiniuUploader = (options) ->

  # support multiple elements
  if @length > 1
    @each ->
      $(this).QiniuUploader options

    return this

  $uploadForm = this

  settings =
    customCallbackData: undefined
    onFilesAdd: undefined
    removeProgressBarWhenCompleted: true
    removeProgressBarWhenFailed: false
    progressBarId: undefined
    buttonId: undefined
    allowMultipleFiles: true

  $.extend settings, options

  submitButtonId =  $uploadForm.data('submit-button-id')
  progressBarId = $uploadForm.data('progress-bar-id')

  submitButton = $('#' + submitButtonId) if submitButtonId
  progressBar = $('#' + progressBarId) if progressBarId

  currentFiles = []
  formsForSubmit = []

  if submitButton and submitButton.length > 0
    submitButton.click ->
      form.submit() for form in formsForSubmit
      false

  generateRandomString= (length) ->
    chars = "abcdefghiklmno0123456789pqrstuvwxyz"
    text = ""
    i = 0
    while i < length
      randomPoz = Math.floor(Math.random() * chars.length)
      text += chars.substring(randomPoz, randomPoz + 1)
      i++
    text

  setUploadForm = ->
    $uploadForm.fileupload

      add: (e, data) ->
        file = data.files[0]
        file.uniqueId = generateRandomString(10) + Math.random().toString(36).substr(2,12)

        unless settings.onFilesAdd and not settings.onFilesAdd(file)
          currentFiles.push data
          if $('#template-upload').length > 0
            data.context = $($.trim(tmpl("template-upload", file)))
            $(data.context).appendTo(progressBar || $uploadForm)
          else if !settings.allowMultipleFiles
            data.context = progressBar
          if submitButton and submitButton.length > 0
            if settings.allowMultipleFiles
              formsForSubmit.push data
            else
              formsForSubmit = [data]
          else
            data.submit()

      start: (e) ->
        $uploadForm.trigger("qiniu_upload_start", [e])

      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 100, 10)
          data.context.find('.bar').css('width', progress + '%')

      done: (e, data) ->
        postData = buildCallbackData $uploadForm, data.files[0], data.result
        callbackUrl = $uploadForm.data('callback-url')
        if callbackUrl
          $.ajax
            type: $uploadForm.data('callback-method')
            url: callbackUrl
            data: postData
            beforeSend: ( xhr, settings )       -> $uploadForm.trigger( 'ajax:beforeSend', [xhr, settings] )
            complete:   ( xhr, status )         -> $uploadForm.trigger( 'ajax:complete', [xhr, status] )
            success:    ( data, status, xhr )   -> $uploadForm.trigger( 'ajax:success', [data, status, xhr] )
            error:      ( xhr, status, error )  -> $uploadForm.trigger( 'ajax:error', [xhr, status, error] )

        data.context.remove() if data.context && settings.removeProgressBarWhenCompleted # remove progress bar
        $uploadForm.trigger("qiniu_upload_complete", [postData])

        currentFiles.splice($.inArray(data, currentFiles), 1) # remove that element from the array
        $uploadForm.trigger("qiniu_upload_complete", [postData]) unless currentFiles.length

      fail: (e, data) ->
        content = buildCallbackData $uploadForm, data.files[0], data.result
        content.errorThrown = data.errorThrown

        data.context.remove() if data.context && settings.removeProgressBarWhenFailed # remove progress bar
        $uploadForm.trigger("qiniu_upload_failed", [postData])

      formData: (form) ->
        data = form.serializeArray()
        #fileType = ""
        #if "type" of @files[0]
          #fileType = @files[0].type
        #data.push
          #name: "x:contentType"
          #value: fileType

        key = $uploadForm.data("key")
          .replace('{timestamp}', new Date().getTime())
          .replace('{unique-id}', @files[0].uniqueId)
          .replace('{filename}', @files[0].name)

        # substitute upload timestamp and uniqueId into key
        keyField = $.grep data, (n) ->
          n if n.name == "key"

        if keyField.length > 0
          keyField[0].value = key

        # IE <= 9 doesn't have XHR2 hence it can't use formData
        # replace 'key' field to submit form
        unless 'FormData' of window
          $uploadForm.find("input[name='key']").val(key)
        data

  buildCallbackData = ($uploadForm, file, result) ->
    content = {}
    content = $.extend content, result if result
    content = $.extend content, settings.customCallbackData if settings.customCallbackData
    content

  #public methods
  @initialize = ->
    # Save key for IE9 Fix
    $uploadForm.data("key", $uploadForm.find("input[name='key']").val())
    setUploadForm()
    this

  @storePath = ->
    newPath = $uploadForm.data('store-path')
    newPath = '/' + newPath if newPath.slice(0, 1) != '/'
    newPath =  newPath + '/' if newPath.slice(-1) != '/'
    newPath

  @customCallbackData = (newData) ->
    settings.customCallbackData = newData

  @initialize()
