local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)

local Constants = require(script.Parent.Parent.Constants)
local Actions = require(script.Parent.Parent.Actions)
local TagManager = require(script.Parent.Parent.TagManager)
local Item = require(script.Parent.ListItem)

local function merge(orig, new)
    local t = {}
    for k,v in pairs(orig or {}) do
        t[k] = v
    end
    for k,v in pairs(new or {}) do
        t[k] = v
    end
    return t
end

local function Tag(props)
    return Roact.createElement(Item, {
        Text = props.Tag,
        Icon = props.Icon,
        IsInput = false,
        LayoutOrder = props.LayoutOrder,
        Visible = props.Visible,
        Active = props.HasAll,
        SemiActive = props.HasSome,
        Hidden = props.Hidden,

        onSetVisible = function()
            TagManager.Get():SetVisible(props.Tag, not props.Visible)
        end,

        onSettings = function()
            props.openTagMenu(props.Tag)
        end,

        leftClick = function(rbx)
            TagManager.Get():SetTag(props.Tag, not props.HasAll)
        end,

        rightClick = function(rbx)
            props.openTagMenu(props.Tag)
        end,
    })
end

Tag = RoactRodux.connect(function(store)
    return {
        openTagMenu = function(tag)
            store:dispatch(Actions.OpenTagMenu(tag))
        end
    }
end)(Tag)

local function Group(props)
    return Roact.createElement(Item, {
        Text = props.Name,
        --Icon = 'folder',
        TextProps = {
            Font = Enum.Font.SourceSansSemibold,
            TextColor3 = Constants.VeryDarkGrey,
        },
        menuOpen = true,
        LayoutOrder = props.LayoutOrder,
        SemiActive = props.Hidden,

        leftClick = function()
            props.toggleHidden(props.Name)
        end,
    })
end

local TagList = Roact.Component:extend("TagList")

function TagList:render()
    local props = self.props

    local function toggleGroup(group)
        self:setState({
            ['Hide'..group] = not self.state['Hide'..group],
        })
    end

    local tags = props.Tags
    table.sort(tags, function(a,b)
        local ag = a.Group or ""
        local bg = b.Group or ""
        if ag < bg then return true end
        if bg < ag then return false end

        local an = a.Name or ""
        local bn = b.Name or ""

        return an < bn
    end)

    local children = {}

    children.UIListLayout = Roact.createElement("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),

        [Roact.Ref] = function(rbx)
            if not rbx then return end
            local function update()
                local cs = rbx.AbsoluteContentSize
                rbx.Parent.CanvasSize = UDim2.new(0, cs.x, 0, cs.y)
            end
            update()
            rbx:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
        end,
    })

    local lastGroup
    local j = 1
    for i = 1, #tags do
        local groupName = tags[i].Group or 'Default'
        if tags[i].Group ~= lastGroup then
            lastGroup = tags[i].Group
            children['Group'..groupName] = Roact.createElement(Group, {
                Name = groupName,
                LayoutOrder = j,
                toggleHidden = toggleGroup,
                Hidden = self.state['Hide'..groupName],
            })
            j = j + 1
        end
        children[tags[i].Name] = Roact.createElement(Tag, merge(tags[i], {
            Hidden = self.state['Hide'..groupName],
            Tag = tags[i].Name,
            LayoutOrder = j,
        }))
        j = j + 1
    end

    local unknownTags = props.unknownTags

    for i = 1, #unknownTags do
        local tag = unknownTags[i]
        children[tag] = Roact.createElement(Item, {
            Text = string.format("%s (click to import)", tag),
            Icon = 'help',
            ButtonColor = Constants.LightRed,
            LayoutOrder = j,
            TextProps = {
                Font = Enum.Font.SourceSansItalic,
                TextColor3 = Constants.White,
            },

            leftClick = function(rbx)
                TagManager.Get():AddTag(tag)
            end,
        })
        j = j + 1
    end

    if #tags == 0 then
        children.NoResults = Roact.createElement(Item, {
            LayoutOrder = j,
            Text = "No search results found.",
            Icon = "cancel",
            TextProps = {
                Font = Enum.Font.SourceSansItalic,
                TextColor3 = Constants.VeryDarkGrey,
            },
        })
        j = j + 1
    end

    local searchTagExists = false
    for i = 1, #tags do
        if tags[i] == props.searchTerm then
            searchTagExists = true
            break
        end
    end
    if props.searchTerm and #props.searchTerm > 0 and not searchTagExists then
        children.AddNew = Roact.createElement(Item, {
            LayoutOrder = j,
            Text = string.format("Add tag %q...", props.searchTerm),
            Icon = "tag_blue_add",

            leftClick = function(rbx)
                TagManager.Get():AddTag(props.searchTerm)
                props.setSearch("")
            end,
        })
    else
        children.AddNew = Roact.createElement(Item, {
            LayoutOrder = j,
            Text = "Add new tag...",
            Icon = "tag_blue_add",
            IsInput = true,

            onSubmit = function(rbx, text)
                TagManager.Get():AddTag(text)
            end,
        })
    end

    return Roact.createElement("ScrollingFrame", {
        Size = props.Size or UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Constants.DarkGrey,
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        BorderSizePixel = 0,
        MidImage = 'rbxasset://textures/ui/Gear.png',
        BottomImage = 'rbxasset://textures/ui/Gear.png',
        TopImage = 'rbxasset://textures/ui/Gear.png',
        VerticalScrollBarInset = Enum.ScrollBarInset.Always,
    }, children)
end

TagList = RoactRodux.connect(function(store)
    local state = store:getState()

    local tags = {}

    for _, tag in pairs(state.TagData) do
        -- todo: LCS
        local passSearch = not state.Search or tag.Name:lower():find(state.Search:lower())
        if passSearch then
            tags[#tags+1] = tag
        end
    end

    local unknownTags = {}
    for _, tag in pairs(state.UnknownTags) do
        -- todo: LCS
        local passSearch = not state.Search or tag:lower():find(state.Search:lower())
        if passSearch then
            unknownTags[#unknownTags+1] = tag
        end
    end

    return {
        Tags = tags,
        searchTerm = state.Search,
        menuOpen = state.TagMenu,
        unknownTags = unknownTags,

        setSearch = function(term)
            store:dispatch(Actions.SetSearch(term))
        end,
    }
end)(TagList)

return TagList
