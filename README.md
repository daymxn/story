<h1 align="center">
	<br>
	<br>
<img width="320" src="./logo.svg"  alt="story logo"/>
	<br>
	<br>
	<br>
</h1>

> Simple UI binding library for Roblox.

![GitHub release (latest by date)](https://img.shields.io/github/v/release/daymxn/story?style=flat-square)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/daymxn/story/main?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/daymxn/story?style=flat-square)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/daymxn/story?style=flat-square)
![GitHub](https://img.shields.io/github/license/daymxn/story?style=flat-square)

---

<br>

## Installation

You can install Story automatically with wally:

```toml
story = "daymxn/story@1.0.0"
```

Alternatively, you can manually install Story by downloading [the latest release](https://github.com/daymxn/story/releases)
and manually inserting it in your project.

## Overview

Story came about as a simple solution for adding logic to an existing UI, while ensuring
proper clean-up procedures were made when instances were destroyed. Especially when it
came to deeply nested UI structures, and external (non rbx) listeners created on individual
UI elements.

Story allows you to easily (and explicitly) define the listeners that should be cleaned up,
as well as other nested UI elements. It also allows you to redraw instances under certain
conditions (such as state updates).

## Alternatives

`What makes this better than React/Roact?`
React is my go-to for new projects, and I highly reccomend it for new projects!
But react falls short when it comes to binding to an already created UI- it's more-so
applicable to creating the UI from code entirely, instead of binding to it externally.

`What about hydration in Fusion?`
Fusion is a great alternative, especially if you're already familiar with it!
But Fusion comes with a lot of behind the scenes magic to make its hydration work,
which is a big part of why they're still not officially released. Story is very
explicit and straightforward with its approach, which makes it easy to not only
diagnose edge-case issues- but also makes it very extensible.

## Features

- Bind UI `Instance`(s) to their respective logic
- Automatically disconnect listners when an `Instance` is destroyed
- Nest UI elements within one another- creating a dependency tree for lifecycle events
- Redraw UI elements on state updates
- Avoid memory leaks when an `Instance` is already destroyed before logic binding

## Usage

Instead of just talking about it, let's show you how Story works in practice.

### Basic Usage

The expected workflow for Story is to perform your bindings from a top-down approach:

```lua
return function Main(main: MainUI)
    return Story.wrap(main, function(story)
        story:AddStory(Pages(main.Pages))
        story:AddStory(Sidebar(main.Sidebar))
    end)
end
```

And then binding your `Main` story to your character:

```lua
Players.LocalPlayer.CharacterAdded:Connect(function(_)
    local ui = MainUI:Clone()

    ui.Parent = game.Players.LocalPlayer.PlayerGui

    Main(ui)
end)
```

From this, Story will automatically perform the cleanup steps necessary whenever
the player respawns and has their UI destroyed.

You may have noticed that you get a `story` variable when wrapping an instance.
This is utilized to add nested Story elements, or attach listeners to specific stories.

For example, lets say we have a vehicle spawning panel. We could define a common button
story for individual vehicle elements, and use `:AddListener` to bind the story with the
`MouseButton1Click` event:

```lua
function Vehicle(button: ImageButton)
    return Story.wrap(button, function(story)
        story:AddListener(button.MouseButton1Click:Connect(function()
            SpawnVehicle:FireServer(button.Name)
        end))
    end)
end
```

With that, we can iterate over all the vehicle buttons and attach this story:

```lua
function VehiclesPage(page: MainUI.Pages.Vehicles)
    return Story.wrap(page, function(story)
        for _, vehicle in page.vehicles:GetChildren() do
            -- Skip layout elements
            if not vehicle:IsA("ImageButton") then continue end
            
            story:AddStory(Vehicle(vehicle))
        end
    end)
end
```

We've attached the individual `Vehicle` story elements to the
`VehiclesPage`'s story with `:AddStory`, so now whenever `VehiclesPage`
is destroyed- the `Vehicle` buttons will be as well.

Although, the story heiarchy is not only useful for cleanup. You can
also force redraws from a top down approach.

For example, what if our vehicles should have an unlocked symbol depending on
if they're actually unlocked?

```lua
function Vehicle(button: ImageButton)
    return Story.wrap(button, function(story)
        local name = button.Name
        local unlocked = table.find(State.UnlockedVehicles, name) ~= nil

        button.Unlocked.Visible = unlocked

        if unlocked then
            story:AddListener(button.MouseButton1Click:Connect(function()
                SpawnVehicle:FireServer(name)
            end))
        end
    end)
end
```

The problem here is that if the vehicle becomes unlocked, since the UI was already
drawn- the `Unlocked` symbol won't be updated, and the `SpawnVehicle` won't be able
to be called.

To solve this, Story provides the `:Redraw` method:

```lua
function VehiclesPage(page: MainUI.Pages.Vehicles)
    return Story.wrap(page, function(story)
        for _, vehicle in page.vehicles:GetChildren() do
            -- Skip layout elements
            if not vehicle:IsA("ImageButton") then continue end
            
            story:AddStory(Vehicle(vehicle))
        end

        -- Add a listener for whenever `State.UnlockedVehicles` is updated
        story:AddListener(onVehiclesUpdated:connect(function()
            story:Redraw()
        end))
    end)
end
```

This will force another "draw" for not only the story itself, but all child stories
added via `:AddStory`.

A "draw" is defined by your call to `wrap`. Specifically, the callback function you provide
is used as the "draw" method. When a story wants to redraw, it will "destroy" itself and nested stories-
effectively wiping the slate clean of listeners and such. Then, it will call the defined "draw"
method to re-define all the listeners and nested stories. From here, the individual `Vehicle` stories
will have the most up-to-date State.

### Advanced Usage

While the standard work-flow will cover 9/10 use cases, there are other scenarios where other
behaviors may be desired. Especially when defining an intermediate API.

#### Manually creating stories

You can also create `Story` instances directly with `new`, and manually bind to the instance
with `:BindToInstance`:

> [!WARNING]
> Instances created with `new` do not have a bound "draw" method, and so can effectively not be
> redrawn by calling `:Redraw`.

```lua
local vehiclesPage = Story.new()
vehiclesPage:BindToInstance(pages.Vehicles)
```

#### Binding to multiple instances

`:BindToInstance` is not limited to an individual instance. You can bind your stories
to _multiple_ instances:

```lua
local vehiclesPage = Story.new()
vehiclesPage:BindToInstance(pages.Vehicles)
vehiclesPage:BindToInstance(game.Players.LocalPlayer.Character)
vehiclesPage:BindToInstance(game:FindFirstChild("map"))
```

And whenever _any_ of the bound instances are destroyed, the `Story` instance will destory itself.

> [!NOTE]
> If an instance is already destroyed whenever you try to initilize it, the `:Destory` method on the story
> will be called immediately. This avoids any potentional memory leaks from listeners created on destroyed
> elements.

#### Manually destroying stories

If, for whatever reason, you want to destory a `Story` instance yourself- you can explicitly call the `:Destroy`
method:

```lua
vehiclesPage:Destroy()
```

#### Custom listeners

Listeners added by `:AddListener` are not limited to `RBXScriptSignal`- a listener only needs to have
a `:Disconnect` method:

```lua
function CustomListener.new(): CustomListener
    local self = {}
    setmetatable(self, CustomListener)

    return self
end

function CustomListener:Disconnect()
  -- do stuff
end


vehiclesPage:AddListener(CustomListener.new())
```

#### Method chaining

All story methods return themselves- which allows for easy method chaining:

```lua
pages:AddStory(vehiclesPage)
     :AddStory(characterPage)
     :AddStory(settingsPage)
```

## Roadmap

- CI testing
- Unit tests
- TypeScript integration
- Webpage for API docs
- Add names to story elements for debugging facilities
  - Add logging to edge-case scenarios with the story name as a point of reference

## License

[Apache 2.0](/LICENSE)
