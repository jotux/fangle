debug = false
dbg = (msg) ->
    if debug isnt true
        return
    console.log(msg)

strip = (text) ->
    if text isnt undefined
        text.replace(/^\s+|\s+/g, "")

GetBlocks = (text) ->
    blocks = text.match(/(\[[a-z0-9=_]*?)\[(.*?)\](.*?\])/g)
    if blocks is null
        return null
    len = blocks.length - 1
    starts = (text.indexOf(blocks[b],0) for b in [0..len])
    lengths = (blocks[b].length for b in [0..len])
    ends = (starts[b] + lengths[b] for b in [0..len])
    {blocks,starts,ends}

GetVariables = (blocks) ->
    len = blocks.length - 1
    names = []
    inits = []
    for b in [0..len]
        vars = blocks[b].match(/\[(.*?)\[/)[1].split("=")
        names[b] = strip(vars[0])
        if vars[1] isnt undefined
            inits[b] = strip(vars[1])
        else
            inits[b] = ""
    {names,inits}

GetTexts = (blocks) ->
    len = blocks.length - 1
    formats = []
    texts = []
    for b in [0..len]
        raw = blocks[b].match(/\](.*).$/)[1]
        raw_split = raw.split(" ")
        if raw[0] is "%" and raw_split[0].length > 1
            formats[b] = raw_split[0]
            texts[b] = raw[formats[b].length..raw.length - 1]
        else
            formats[b] = ""
            texts[b] = raw
    {texts,formats}

GetConfigs = (blocks) ->
    len = blocks.length - 1
    # Types are: NumberBox,AdjustableNumber,Toggle,Resultant,If,Switch,Variable
    # Short description: N, A, T, R, I, S, V
    types = []
    mins = []
    maxs = []
    steps = []
    conds = []
    exprs = []
    for b in [0..len]
        config = blocks[b].match(/\[.+\[(.*?)\].*\]/)
        types[b] = GetConfigType(config)
        mins[b] = ""
        maxs[b] = ""
        steps[b] = ""
        conds[b] = ""
        exprs[b] = ""
        switch(types[b])
            when "S","I"
                conds[b] = config[1].replace /([a-zA-Z_]+.*?)/g, (match) ->
                    AddThisTo(match)
            when "R"
                exprs[b] = config[1].replace /([a-zA-Z_]+.*?)/g, (match) ->
                    AddThisTo(match)
            when "A"
                range_info = config[1].split("..")
                step_info = range_info[1].split(",")
                if step_info.length > 1
                    steps[b] = step_info[1]
                    mins[b] = range_info[0]
                    maxs[b] = step_info[0]
                else
                    mins[b] = range_info[0]
                    maxs[b] = range_info[1]
    {types,mins,maxs,steps,conds,exprs}

GetConfigType = (config) ->
    if config[1] is ""
        type = "V"
    else if config[1] is "_"
        type = "N"
    else if config[1] is "0,1"
        type = "T"
    else if config[1].split("..").length > 1
        type = "A"
    else if /[><|&=!]/.test(config[1]) is true and config[1].split(",").length > 1
        type = "S"
    else if /[><|&=!]/.test(config[1]) is true
        type = "I"
    else if /[\*|\+|\-|\/|\^]|^\S+/.test(config[1]) is true
        type = "R"
    else
        type = "U"

AddThisTo = (text) ->
    if text is undefined
        return
    text = "this.#{text}"

GetHtmJs = (raw,blocks,variables,texts,configs) ->
    inits = ""
    updates = ""
    htm = raw[0..blocks['starts'][0] - 1]
    len = blocks['starts'].length - 1
    for b in [0..len]
        switch configs['types'][b]
            when "V"
                if variables['inits'][b] isnt ""
                    inits += "#{AddThisTo(variables['names'][b])}=#{variables['inits'][b]};"
                else
                    inits += "#{AddThisTo(variables['names'][b])}=0"
            when "R"
                updates += "#{AddThisTo(variables['names'][b])}=#{configs['exprs'][b]};"
                htm += "<span data-var=\"#{variables['names'][b]}\""
                htm += " data-format=\"#{texts['formats'][b]}\"" if texts['formats'][b] isnt ""
                htm += ">#{texts['texts'][b]}</span>"
            when "A"
                if variables['inits'][b] isnt ""
                    inits += "#{AddThisTo(variables['names'][b])}=#{variables['inits'][b]};"
                else
                    inits += "#{AddThisTo(variables['names'][b])}=#{configs['mins'][b]};"
                htm += "<span data-var=\"#{variables['names'][b]}\""
                htm += " class=\"TKAdjustableNumber\" "
                htm += " data-min=\"#{configs['mins'][b]}\"" if configs['mins'][b] isnt ""
                htm += " data-max=\"#{configs['maxs'][b]}\"" if configs['maxs'][b] isnt ""
                htm += " data-step=\"#{configs['steps'][b]}\"" if configs['steps'][b] isnt ""
                htm += " data-format=\"#{texts['formats'][b]}\"" if texts['formats'][b] isnt ""
                htm += ">#{texts['texts'][b]}</span>"
            when "N"
                if variables['inits'][b] isnt ""
                    inits += "#{AddThisTo(variables['names'][b])}=#{variables['inits'][b]};"
                else
                    inits += "#{AddThisTo(variables['names'][b])}=0;"
                htm += "<span data-var=\"#{variables['names'][b]}\""
                htm += " class=\"TKNumberField\"></span>"
            when "T"
                if variables['inits'][b] isnt ""
                    inits += "#{AddThisTo(variables['names'][b])}=#{variables['inits'][b]};"
                else
                    inits += "#{AddThisTo(variables['names'][b])}=0;"
                htm += "<span data-var=\"#{variables['names'][b]}\""
                htm += " class=\"TKToggle TKSwitch\">"
                toggle_text = texts['texts'][b].split(",")
                htm += "<span>#{toggle_text[0]}</span>"
                htm += "<span>#{toggle_text[1]}</span>"
                htm += "</span>"
            when "I"
                updates += "#{AddThisTo(variables['names'][b])}=#{configs['conds'][b]};"
                htm += "<span data-var=\"#{variables['names'][b]}\""
                htm += " class=\"TKIf\" "
                htm += ">#{texts['texts'][b]}</span>"
            when "S"
                switch_updates = configs['conds'][b].split(",")
                switch_texts = texts['texts'][b].split(",")
                s_len = switch_updates.length - 1
                htm += "<span data-var=\"#{variables['names'][b]}\" class=\"TKSwitch\">"
                for s in [0..s_len]
                    updates += "if (#{switch_updates[s]}){#{AddThisTo(variables['names'][b])}=#{s};}"
                    updates += "else " if s isnt s_len
                    htm += "<span>#{switch_texts[s]}</span>"
                htm += "</span>"
            # TODO add supprt for "U"
        htm += raw[blocks['ends'][b]..blocks['starts'][b + 1] - 1] if (b <= len)
    js = "{initialize: function () {#{inits}},update: function (){#{updates}}}"
    {js,htm}

ParseReactive = (raw) ->
    try
        dbg("Get blocks")
        blocks = GetBlocks(raw)
        if blocks is null
            return null
        dbg("Get vars and inits")
        variables = GetVariables(blocks['blocks'])
        dbg("Get text and format")
        texts = GetTexts(blocks['blocks'])
        dbg("Get config info")
        configs = GetConfigs(blocks['blocks'])
        dbg("Get js and htm")
        GetHtmJs(raw,blocks,variables,texts,configs)
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