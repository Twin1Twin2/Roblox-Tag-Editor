local Actions = require(script.Parent.Parent.Actions)

return function(state, action)
    state = state or nil

    if action.Type == Actions.ToggleIconPicker then
        return action.Tag
    end

    return state
end
