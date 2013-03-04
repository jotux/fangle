debug = true
dbg = (msg) ->
    if debug isnt true
        return
    console.log(msg)

strip = (text) ->
    if text isnt undefined
        text.replace(/^\s+|\s+/g, "")

GetBlocks = (text) ->
    blocks = text.match(/\[\[(.*?)\]\]/g)
    if blocks is null
        return null
    len = blocks.length - 1
    dbg("    Blocks found: " + len)
    index = (text.indexOf(blocks[b],0) for b in [0..len])
    size = (blocks[b].length for b in [0..len])
    {blocks,index,size}

ParseReactive = (raw) ->
    try
        dbg("Get blocks")
        blocks = GetBlocks(raw)
        dbg(blocks)
        if blocks is null
            return null
    catch error
        dbg("Parsing Error #{error}")
        return null

tangle = {}
model = {}

MdToHtml = (raw) ->
    try
        converter = new Showdown.converter()
        htm = converter.makeHtml(raw)
    catch error
        dbg("Markdown convertion error #{error}")
        return raw

UpdateModel = (model) ->
    element = document.getElementById("t1")
    tangle = new Tangle(element,model)

# Everything below this line should be abstracted out to the main page or a different script. Everything above should probably be moved into a class
RunParse = ->
    raw = "\n" + $("#input").val()
    r = ParseReactive(raw)
    if r isnt null
        try
            htm = MdToHtml(r['htm'])
            eval("model =" + r['js'])
            $("#output").html(htm)
            UpdateModel(model)
        catch error
            dbg("Model loading error #{error}")
            htm = MdToHtml(raw)
            $("#output").html(htm)
    else
        htm = MdToHtml(raw)
        $("#output").html(htm)

oldtext = ""
newtext = ""

CheckForChanges = ->
    newtext = $("#input").val()
    if newtext isnt oldtext
        RunParse()
    oldtext = newtext
    setTimeout CheckForChanges, 300

$("#car_ex").click = ->
    alert("test")

$ ->
    model =
        initialize: ->
            return
        update: ->
            return
    element = document.getElementById("t1")
    tangle = new Tangle(element,model)
    CheckForChanges()