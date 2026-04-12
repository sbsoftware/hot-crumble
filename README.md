# hot-crumble

[![Discord](https://img.shields.io/badge/Discord-Join%20chat-5865F2?logo=discord&logoColor=white)](https://discord.gg/8kVNHQB9nD)

`hot-crumble` is a batteries-included Crystal toolkit for building interactive web apps with typed pages, typed models, and Turbo-powered actions. It is aimed at developers who want to move quickly from schema to UI and ship dynamic, real-time-feeling applications from a compact codebase.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     hot-crumble:
       github: sbsoftware/hot-crumble
   ```

2. Run `shards install`

## Usage

```crystal
require "hot-crumble"
```

`hot-crumble` bundles the pieces you need to build dynamic apps in one place:

- `Crumble::Page` for routeable pages and UI composition
- `Orma::Record` for typed models and persistence
- Turbo actions and model actions for interactive updates
- typed HTML, CSS, and JavaScript helpers for keeping UI code in Crystal

Routes are derived from class names by default, model-aware pages can load records directly from the URL, and model actions can update part of the page while broadcasting Turbo stream refreshes to connected clients.

## Example App

The following example is designed to be pasted into a fresh folder and run as a tiny app. It shows:

- a `Project` model
- a `Task` model
- a `ProjectPage` that loads a model from the route
- a `create_child_action` for adding tasks
- a `boolean_flip_action` for toggling a task between open and done
- scoped inline styles

### `shard.yml`

```yaml
name: demo_board
version: 0.1.0

targets:
  demo_board:
    main: src/demo_board.cr

dependencies:
  sqlite3:
    github: crystal-lang/crystal-sqlite3
  hot-crumble:
    github: sbsoftware/hot-crumble
```

### File layout

```text
.
├── shard.yml
└── src
    ├── demo_board.cr
    ├── models
    │   ├── application_record.cr
    │   ├── project.cr
    │   └── task.cr
    ├── pages
    │   ├── application_page.cr
    │   ├── home_page.cr
    │   └── project_page.cr
    └── views
        └── application_layout.cr
```

### `src/demo_board.cr`

```crystal
require "sqlite3"
require "hot-crumble"
require "./models/**"
require "./views/**"
require "./pages/**"

if Project.all.empty?
  project = Project.create(name: "Launch checklist")
  Task.create(project_id: project.id.value, title: "Write the landing page")
  Task.create(project_id: project.id.value, title: "Add live task updates")
end

Crumble::Server.start
```

### `src/models/application_record.cr`

```crystal
abstract class ApplicationRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end
end
```

### `src/models/task.cr`

```crystal
class Task < ApplicationRecord
  column project_id : Int64
  column title : String
  column done : Bool = false

  css_class TaskRow
  css_class TaskStatus
  css_class TaskTitle

  model_template :row_view do
    li TaskRow do
      strong TaskStatus do
        done.value ? "DONE" : "OPEN"
      end
      span TaskTitle do
        title.value
      end
      switch_done_action_template(ctx).to_html
    end
  end

  boolean_flip_action :switch_done, :done, :row_view do
    view do
      template do
        custom_action_trigger.to_html do
          button { model.done.value ? "Mark open" : "Mark done" }
        end
      end
    end
  end

  style do
    rule TaskRow do
      display :flex
      align_items :center
      gap 12.px
      padding_top 10.px
      padding_bottom 10.px
      border_bottom 1.px, :solid, "#e2e8f0"
    end

    rule TaskStatus do
      font_size 12.px
      font_weight 700
      color "#475569"
      letter_spacing 0.08.em
    end

    rule TaskTitle do
      flex_grow 1
    end
  end
end
```

### `src/models/project.cr`

```crystal
class Project < ApplicationRecord
  column name : String

  css_class Card
  css_class TaskList
  css_class Errors

  def tasks
    Task.where(project_id: id.value).order_by_id!
  end

  create_child_action :add_task, Task, project_id, tasks_view do
    form do
      field title : String, label: "Task title", allow_blank: false
    end

    view do
      template do
        action_form(hidden: false).to_html do
          if errors = action.form.errors
            div Errors do
              "Please enter a title."
            end
          end

          button { "Add task" }
        end
      end
    end
  end

  model_template :tasks_view do
    section Card do
      h2 { "Tasks" }

      ul TaskList do
        tasks.each do |task|
          task.row_view.renderer(ctx)
        end
      end

      add_task_action_template(ctx).to_html
    end
  end

  style do
    rule Card do
      background_color :white
      border_radius 20.px
      padding 24.px
      box_shadow 0.px, 18.px, 45.px, rgb(15, 23, 42, alpha: 8.percent)
    end

    rule TaskList do
      list_style :none
      padding_left 0.px
    end

    rule Errors do
      margin_bottom 12.px
      color "#b91c1c"
      font_weight 600
    end

    rule button do
      background_color "#2563eb"
      color :white
      border :none
      border_radius 999.px
      padding_top 10.px
      padding_bottom 10.px
      padding_left 14.px
      padding_right 14.px
      cursor :pointer
    end

    rule input do
      width 100.percent
      max_width 320.px
      padding_top 10.px
      padding_bottom 10.px
      padding_left 12.px
      padding_right 12.px
      margin_bottom 12.px
      border 1.px, :solid, "#cbd5e1"
      border_radius 12.px
      box_sizing :border_box
    end
  end
end
```

### `src/views/application_layout.cr`

```crystal
class ApplicationLayout < ToHtml::Layout
end
```

### `src/pages/application_page.cr`

```crystal
abstract class ApplicationPage < Crumble::Page
  layout ApplicationLayout
end
```

### `src/pages/home_page.cr`

```crystal
class HomePage < ApplicationPage
  root_path "/"

  css_class ProjectList

  template do
    main do
      h1 { "Demo board" }
      p { "Open the seeded project to try pages, models, and actions together." }

      ul ProjectList do
        Project.all.order_by_id!.each do |project|
          li do
            a href: ProjectPage.uri_path(project_id: project.id.value) do
              project.name.value
            end
          end
        end
      end
    end
  end

  style do
    rule body do
      margin 0.px
      background_color "#f3f6fb"
      color "#1f2937"
      font_family "IBM Plex Sans", "Segoe UI", :sans_serif
      line_height 1.5
    end

    rule main do
      max_width 720.px
      margin_top 48.px
      margin_bottom 48.px
      margin_left :auto
      margin_right :auto
      padding_left 24.px
      padding_right 24.px
    end

    rule h1 do
      margin_bottom 8.px
      font_size 32.px
    end

    rule a do
      color "#2563eb"
    end

    rule ProjectList do
      background_color :white
      border_radius 20.px
      padding 24.px
      box_shadow 0.px, 18.px, 45.px, rgb(15, 23, 42, alpha: 8.percent)
    end
  end
end
```

### `src/pages/project_page.cr`

```crystal
class ProjectPage < ApplicationPage
  model project : Project

  template do
    main do
      h1 { project.name }

      p do
        a href: HomePage.uri_path do
          "Back to projects"
        end
      end

      project.tasks_view.renderer(ctx).to_html
    end
  end
end
```

### Run it

```bash
shards install
DATABASE_URL='sqlite3://./demo_board.db' ORMA_CONTINUOUS_MIGRATION=1 crystal run src/demo_board.cr
```

Then open `http://localhost:8080`.

`DATABASE_URL` points Orma at the SQLite database file. PostgreSQL works as well when the corresponding DB shard is required. `ORMA_CONTINUOUS_MIGRATION=1` tells Orma to create or update the example tables while the app boots.

### How the example fits together

- `HomePage` resolves to `/` and links to `ProjectPage`
- `ProjectPage` loads a `Project` from the route via `model project : Project`
- `Project#tasks_view` renders the current task list plus the create form
- `Project#add_task` is a model-aware action that inserts a `Task` and refreshes `tasks_view`
- `Task#switch_done` flips one boolean attribute and refreshes only that task row

## Included Extras

Beyond pages, models, and actions, `hot-crumble` also bundles:

- `crumble-crababel` for localized labels and page content
- `crumble-jobs` for background jobs and retries
- `crumble-stimulus` for typed Stimulus controllers in Crystal
- `css.cr`, `js.cr`, and `to_html.cr` for typed UI building blocks

## Development

- Install dependencies: `shards install`
- Run tests: `crystal spec`

## Contributors

- [Stefan Bilharz](https://github.com/sbsoftware) - creator and maintainer
