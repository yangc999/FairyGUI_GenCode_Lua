local genCocosLua = require(PluginPath.."/genCocosLua")
local genUnityLua = require(PluginPath.."/genUnityLua")

function onPublish(handler)
    if not handler.genCode or handler.publishDescOnly then
        return
    end

    handler.genCode = false --prevent default output
    App.consoleView:Clear()
    fprint("Handling gen lua code in plugin.")
    if App.project.type == ProjectType.Cocos2dx then
        genCocosLua(handler)
    elseif App.project.type == ProjectType.Unity then
        genUnityLua(handler)
    else
        fprint("not supported yet.")
    end
end

function genCode(handler)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local codePkgName = handler:ToFilename(handler.pkg.name); --convert chinese to pinyin, remove special chars etc.
    local exportCodePath = handler.exportCodePath .. '/' .. codePkgName
    local lua_file_extension_name = get_project_custom_property_value(customPropKeys.key_lua_file_extension_name.name);
    local lua_path_root = get_project_custom_property_value(customPropKeys.key_lua_path_root.name);
    lua_path_root = string.gsub(lua_path_root, "/", ".");
    lua_path_root = string.gsub(lua_path_root, "\\", ".");

    local namespaceName = codePkgName
    local key_wrapper_namespace = get_project_custom_property_value(customPropKeys.key_wrapper_namespace.name);

    if settings.packageName ~= nil and settings.packageName ~= '' then
        namespaceName = settings.packageName .. '.' .. namespaceName;
    end

    --CollectClasses(stripeMemeber, stripeClass, fguiNamespace)
    local classes = handler:CollectClasses(settings.ignoreNoname, settings.ignoreNoname, key_wrapper_namespace)
    handler:SetupCodeFolder(exportCodePath, lua_file_extension_name) --check if target folder exists, and delete old files

    local getMemberByName = settings.getMemberByName
    local classTemplateTxt = CS.System.IO.File.ReadAllText(PluginPath .. "/component_template.txt")
    if (classTemplateTxt == "") then
        fprint("component_template.txt content null.")
        return
    end

    local classCnt = classes.Count
    local writer = LuaCodeWriter.new({ blockFromNewLine = false, usingTabs = true })
    for i = 0, classCnt - 1 do
        local _classTemplateTxt = classTemplateTxt;
        local classInfo = classes[i]
        local members = classInfo.members
        writer:reset()

        _classTemplateTxt = string.gsub(_classTemplateTxt, "$className", classInfo.className);
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$superClassName", classInfo.superClassName);
        -- if (key_wrapper_namespace ~= "") then
        --     _classTemplateTxt = string.gsub(_classTemplateTxt, "$namespace", key_wrapper_namespace .. ".");
        -- else
        --     _classTemplateTxt = string.gsub(_classTemplateTxt, "$namespace", "");
        -- end

        local _classFieldAnnotation = string.format('---@field public %s %s\n', "__ui", classInfo.superClassName);
        local memberCnt = members.Count
        for j = 0, memberCnt - 1 do
            if (j > 0) then
                _classFieldAnnotation = _classFieldAnnotation .. "\n";
            end
            local memberInfo = members[j]
            _classFieldAnnotation = _classFieldAnnotation .. string.format('---@field public %s %s', memberInfo.varName, memberInfo.type);
        end

        _classTemplateTxt = string.gsub(_classTemplateTxt, "$classFieldAnnotation", _classFieldAnnotation);

        local _urlValue = string.format('"ui://%s%s"', handler.pkg.id, classInfo.classId)
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$urlValue", _urlValue);

        _classTemplateTxt = string.gsub(_classTemplateTxt, "$uiPackageName", handler.pkg.name);
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$uiResName", classInfo.resName);

        local _classFieldInstatiation = "";
        for j = 0, memberCnt - 1 do
            local memberInfo = members[j]
            if j > 0 then
                _classFieldInstatiation = _classFieldInstatiation .. "\n";
            end
            _classFieldInstatiation = _classFieldInstatiation .. "\t";
            if memberInfo.group == 0 then
                if getMemberByName then
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetChild("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetChildAt("%s");', memberInfo.varName, memberInfo.index);
                end
            elseif memberInfo.group == 1 then
                if getMemberByName then
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetController("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetControllerAt("%s");', memberInfo.varName, memberInfo.index);
                end
            else
                if getMemberByName then
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetTransition("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classFieldInstatiation = _classFieldInstatiation .. string.format('self.%s = self:GetTransitionAt("%s");', memberInfo.varName, memberInfo.index);
                end
            end
        end
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$classFieldInstantiation", _classFieldInstatiation);
        writer:writeln('%s', _classTemplateTxt);

        writer:save(exportCodePath .. '/' .. classInfo.className .. '.' .. lua_file_extension_name)
    end

    writer:reset()

    local binderTemplateTxt = CS.System.IO.File.ReadAllText(PluginPath .. "/binder_template.txt");
    if (binderTemplateTxt == "") then
        fprint("binder_template.txt content null.")
        return ;
    end
    local binderName = codePkgName .. 'Binder'

    local _requireStatement = "";

    for i = 0, classCnt - 1 do
        if (i > 0) then
            _requireStatement = _requireStatement .. "\n";
        end
        local classInfo = classes[i]
        _requireStatement = _requireStatement .. string.format('%s = require("%s%s.%s");', classInfo.className, lua_path_root, codePkgName, classInfo.className);
    end

    binderTemplateTxt = string.gsub(binderTemplateTxt, "$requireStatement", _requireStatement);
    binderTemplateTxt = string.gsub(binderTemplateTxt, "$binderClassName", binderName);

    local _bindStatement = "";
    for i = 0, classCnt - 1 do
        if (i > 0) then
            _bindStatement = _bindStatement .. "\n";
        end
        local classInfo = classes[i]
        _bindStatement = _bindStatement .. "\t";

        _bindStatement = _bindStatement .. string.format('fgui.register_extension(%s.URL, %s);', classInfo.className, classInfo.className);
        -- if (key_wrapper_namespace ~= "") then
        --     _bindStatement = _bindStatement .. string.format('%sUIObjectFactory.SetPackageItemExtension(%s.URL, %s);', key_wrapper_namespace .. ".", classInfo.className, classInfo.className);
        -- else
        --     _bindStatement = _bindStatement .. string.format('UIObjectFactory.SetPackageItemExtension(%s.URL, %s);', classInfo.className, classInfo.className);
        -- end

    end
    binderTemplateTxt = string.gsub(binderTemplateTxt, "$bindStatement", _bindStatement);
    writer:writeln('%s', binderTemplateTxt);
    writer:save(exportCodePath .. '/' .. binderName .. '.' .. lua_file_extension_name)

    writer:reset()

    local _readSuccess, _initTxt = pcall(function()
        return CS.System.IO.File.ReadAllText(handler.exportCodePath .. "/init.lua");
    end);
    if(not _readSuccess) then
        _initTxt = "";
    end
    local _requireStatement = string.format('local %s = require("%s%s.%s");',binderName, lua_path_root,codePkgName, binderName);
    _requireStatement = _requireStatement .. string.format('\n%s:BindAll();',binderName);
    if(string.find(_initTxt,_requireStatement,1,true) == nil) then
        _requireStatement = _requireStatement .. "\n";
        _initTxt = _initTxt .. _requireStatement;
        CS.System.IO.File.WriteAllText(handler.exportCodePath .. "/init.lua", _initTxt);
    end
end

function onDestroy()
    -------do cleanup here-------
end