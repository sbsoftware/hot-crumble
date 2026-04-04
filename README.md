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

if Project.count == 0
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

  model_template :row_view do
    li do
      strong { done ? "DONE" : "OPEN" }
      text " "
      span { title }
      text " "
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
end
```

### `src/models/project.cr`

```crystal
class Project < ApplicationRecord
  column name : String

  def tasks
    Task.where(project_id: id.value).order_by_id!
  end

  create_child_action :add_task, Task, project_id, tasks_view do
    form do
      field title : String, allow_blank: false
    end

    view do
      template do
        action_form(hidden: false).to_html do
          if errors = action.form.errors
            div class: "errors" do
              "Please enter a title."
            end
          end

          button { "Add task" }
        end
      end
    end
  end

  model_template :tasks_view do
    section do
      h2 { "Tasks" }

      ul do
        tasks.each do |task|
          task.row_view.renderer(ctx)
        end
      end

      add_task_action_template(ctx).to_html
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
  template do
    main do
      h1 { "Demo board" }
      p { "Open the seeded project to try pages, models, and actions together." }

      ul do
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
