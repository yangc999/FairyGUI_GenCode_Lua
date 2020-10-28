local luaWriterConfig = {}
luaWriterConfig.fileMark = '-- This is an automatically generated class by FairyGUI. Please do not modify it.'

local function genComponent(exportCodePath, handler, classInfo)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local getMemberByName = settings.getMemberByName
    local members = classInfo.members
    -- local references = classInfo.references
    local writer = CodeWriter.new(luaWriterConfig)
    local memberCnt = members.Count
    writer:writeln(string.format('local %s = fgui.extension_class()', classInfo.className))
    writer:writeln(string.format('rawset(%s, "__cname", "%s")', classInfo.className, classInfo.className))
    writer:writeln()
    local _urlValue = string.format('"ui://%s%s"', handler.pkg.id, classInfo.resId)
    writer:writeln(string.format('%s.URL = %s', classInfo.className, _urlValue))
    writer:writeln()
    writer:writeln(string.format('function %s:__create()', classInfo.className))
    writer:incIndent()
    writer:writeln(string.format('return fgui.UIPackage:createObject("%s", "%s")', handler.pkg.name, classInfo.resName))
    writer:decIndent()
    writer:writeln('end')
    writer:writeln()
    writer:writeln(string.format('function %s:ctor()', classInfo.className))
    writer:incIndent()
    for i=0,memberCnt-1 do
        local memberInfo = members[i]
        if memberInfo.group==0 then
            if getMemberByName then
                writer:writeln('self.%s = self:getChild("%s")', memberInfo.varName, memberInfo.name)
            else
                writer:writeln('self.%s = self:getChildAt(%s)', memberInfo.varName, memberInfo.index)
            end
        elseif memberInfo.group==1 then
            if getMemberByName then
                writer:writeln('self.%s = self:getController("%s")', memberInfo.varName, memberInfo.name)
            else
                writer:writeln('self.%s = self:getControllerAt(%s)', memberInfo.varName, memberInfo.index)
            end
        else
            if getMemberByName then
                writer:writeln('self.%s = self:getTransition("%s")', memberInfo.varName, memberInfo.name)
            else
                writer:writeln('self.%s = self:getTransitionAt(%s)', memberInfo.varName, memberInfo.index)
            end
        end
    end
    writer:decIndent()
    writer:writeln('end')
    writer:writeln()
    writer:writeln(string.format('return %s', classInfo.className))
    writer:save(exportCodePath..'/'..classInfo.className..'.lua')
end

local function genBinder(exportCodePath, classes, codePkgName, binderName)
    local writer = CodeWriter.new(luaWriterConfig)
    local classCnt = classes.Count
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln(string.format('local %s = require("%s.%s")', classInfo.className, codePkgName, classInfo.className))
    end
    writer:writeln()
    writer:writeln(string.format('local %s = class("%s")', binderName, binderName))
    writer:writeln()
    writer:writeln(string.format('function %s:BindAll()', binderName))
    writer:incIndent()
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln(string.format('fgui.register_extension(%s.URL, %s)', classInfo.className, classInfo.className))
    end
    writer:decIndent()
    writer:writeln('end')
    writer:writeln()
    writer:writeln(string.format('return %s', binderName))
    writer:save(exportCodePath..'/'..binderName..'.lua')
end

local function genCode(handler)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local codePkgName = handler:ToFilename(handler.pkg.name) --convert chinese to pinyin, remove special chars etc.
    local exportCodePath = handler.exportCodePath..'/'..codePkgName
    local namespaceName = codePkgName
    local binderName = codePkgName..'Binder'

    if settings.packageName~=nil and settings.packageName~='' then
        namespaceName = settings.packageName..'.'..namespaceName
    end

    --CollectClasses(stripeMemeber, stripeClass, fguiNamespace)
    local classes = handler:CollectClasses(settings.ignoreNoname, settings.ignoreNoname, nil)
    handler:SetupCodeFolder(exportCodePath, "lua") --check if target folder exists, and delete old files

    local classCnt = classes.Count
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        genComponent(exportCodePath, handler, classInfo)
    end

    genBinder(exportCodePath, classes, codePkgName, binderName)

end

return genCode