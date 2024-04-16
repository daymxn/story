--[[
    Create UI Stories and bind them to each other or instances.

    A story is a UI element that can be built via a single function.
    This allows for the UI to be easily bound to Instance lifecycles,
    other Story lifecycles, or even state changes.

    Note that all public methods will return the Story instance itself,
    to allow easy method chaining.

    @module Story
    @author daymxn
]]

export type Story = {
    new: () -> Story,
    wrap: (instance: Instance, draw: StoryCallback) -> Story,
    AddListener: (self: Story, listener: any) -> Story,
    AddStory: (self: Story, story: Story) -> Story,
    BindToInstance: (self: Story, instance: Instance) -> Story,
    Destroy: (self: Story) -> Story,
    Draw: (self: Story) -> Story,
    Redraw: (self: Story) -> Story,
}

export type StoryCallback = (story: Story) -> ()

local Story: Story = {}
Story.__index = Story

--[[
    Checks if an Instance is already destroyed.

    There's no property for checking if an Instance is destroyed.
    Technically, you can check if the `Instance.Parent` is set to
    `nil`- but this isn't a surefire way. Beyond developers manually
    setting the `Parent`, a big edge case is when `Instance`(s) are in
    the middle of being created.

    When an Instance is *actually* destroyed, its `Parent` property is
    locked. So any attempt to change it will throw an error. By attempting
    to set the `Parent` property to itself, we have a no-op action to
    check if an Instance is destroyed.
]]
local function isInstanceDestroyed(instance: Instance): boolean
    local success, _ = pcall(function()
        instance.Parent = instance.Parent
    end)

    return not success
end

--[[
    Create a new Story instance.

    You rarely want to actually use this method.
    You typically want to use `Story.wrap` instead.

    @see Story.wrap
]]
function Story.new(): Story
    local self = {}
    setmetatable(self, Story)

    self._rootInstance = nil
    self._destroyed = false
    self._listeners = {}
    self._stories = {}
    self._draw = nil

    return self
end

--[[
    Create a new Story Instance bound to a given instance.

    This story will be destroyed when the provided instance is destroyed,
    and all listeners created under this story will be disconnected.
    Additionally, any stories created under this instance will be destroyed
    as well.

    The provided `draw` method is used to invoke the populating of the UI
    for this story.

    Example Usage:
    ```lua
    Story.wrap(pages, function(story)
        story:AddStory(vehiclePage(pages.VehiclePage))
        story:AddListener(pageChangedSignal:Connect(function (newPage)
            -- ...
        end))
    end)
    ```

    @returns The newly created Story instance
]]
function Story.wrap(instance: Instance, draw: StoryCallback): Story
    local story = Story.new()
    story._rootInstance = instance

    story:_wrap(instance, draw)

    return story
end

--[[
    Runs the draw method for the story.

    This method should only be used for drawing specifically-
    listeners will not be unbound and child stories will not be
    destroyed. Use `self.Redraw` if you're wanting to invoke the
    drawing again.

    *If the story has already been destroyed, nothing will be drawn.*

    @see self.Redraw
]]
function Story:Draw(): Story
    if self._destroyed then return self end

    if self._draw then self._draw(self) end

    return self
end

--[[
    Redraws the story.

    Will unbind all the listeners and child stories, and then
    recreate them by running the draw method attached to this
    story.

    Intended to be used to update UIs that depend on some defined
    parent state.

    Example Usage:
    ```lua
    Story.wrap(settingsPage, function(story)
        story:AddListener(settingsUpdated:Connect(function()
            story:Redraw()
        end))
    end)
    ```
]]
function Story:Redraw(): Story
    if not self._draw or not self._rootInstance then return self end

    self:_detach()

    self:_wrap(self._rootInstance, self._draw)

    return self
end

--[[
    Binds the story to the provided Instance.

    When the Instance is destroyed, this story will also
    be destroyed.

    You can bind to more than one instance; whenever *any* of
    the instances you've bound to are destroyed, then the story
    will also be destroyed.

    *If the story is already destroyed, then the story will be destroyed as well*

    @see Story.Destroy
]]
function Story:BindToInstance(instance: Instance): Story
    if self._destroyed then return self end
    if isInstanceDestroyed(instance) then return self:Destroy() end

    self:AddListener(instance.Destroying:Once(function()
        self:Destroy()
    end))

    return self
end

--[[
    Keeps track of a Listener to disconnect when this story is destroyed.

    A listener doesn't necessarily need to be a `RBXScriptSignal`, a listener
    only needs to have a `:Disconnect()` method.

    *If the story is already destroyed, then this listener will be immediately
    disconnected*

    @see Story.Destroy
    @see Story.AddStory
]]
function Story:AddListener(listener): Story
    if self._destroyed then
        listener:Disconnect()

        return self
    end

    table.insert(self._listeners, listener)

    return self
end

--[[
    Keeps track of another story to destroy when this story is destroyed.

    *If this story is already destroyed, then this provided story will be immediately
    destroyed as well*

    @see Story.Destroy
    @see Story.AddListener
]]
function Story:AddStory(story: Story): Story
    if self._destroyed then
        story:Destroy()

        return self
    end

    table.insert(self._stories, story)

    return self
end

--[[
    Detaches all listeners bound to this story, and marks it as destroyed.

    Once a story has been marked as destroyed, it can no longer be used.
    Any further attempt to use it will result in a no-op.

    The root instance reference is also set to nil to allow the garbage collector
    to collect it.

    @see Story.AddListener
    @see Story.AddStory
]]
function Story:Destroy(): Story
    if self._destroyed then return self end

    self._destroyed = true
    self._rootInstance = nil
    self:_detach()

    return self
end

function Story:_detach()
    self:_detachListeners()
    self:_detachStories()
end

function Story:_detachListeners()
    for _, listener in self._listeners do
        listener:Disconnect()
    end

    self._listeners = {}
end

function Story:_detachStories()
    for _, story in self._stories do
        story:Destroy()
    end

    self._stories = {}
end

function Story:_wrap(instance: Instance, draw)
    self:BindToInstance(instance)
    self._draw = draw
    self:Draw()
end

setmetatable(Story, {
    __index = function(_, key)
        error(`Attempted to get Story::{key} (which is not a valid member)`, 2)
    end,
    __newindex = function(_, key, _)
        error(`Attempted to set Story::{key} (which is not a valid member)`, 2)
    end,
})

return table.freeze({
    new = Story.new,
    wrap = Story.wrap,
})
