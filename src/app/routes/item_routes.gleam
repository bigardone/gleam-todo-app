import app/models/item.{type Item, create}
import app/web.{type Context, Context}
import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

type ItemJson {
  ItemJson(id: String, litle: String, completed: Bool)
}

pub fn items_middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Context) -> Response,
) {
  let parsed_items = {
    case wisp.get_cookie(req, "items", wisp.PlainText) {
      Ok(json_string) -> {
        let result = json.decode(json_string, items_decoder())

        case result {
          Ok(items) -> items
          Error(_) -> []
        }
      }
      Error(_) -> []
    }
  }

  let items = create_items_from_json(parsed_items)

  let ctx = Context(..ctx, items: items)

  handle_request(ctx)
}

pub fn post_create_item(req: Request, ctx: Context) {
  use form <- wisp.require_form(req)

  let current_items = ctx.items

  let result = {
    use item_title <- result.try(list.key_find(form.values, "todo_title"))

    let new_item = create(None, item_title, False)

    current_items
    |> list.append([new_item])
    |> todos_to_json()
    |> Ok
  }

  case result {
    Ok(todos) -> {
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", todos, wisp.PlainText, 60 * 60 * 24)
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

pub fn delete_item(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let json_items = {
    list.filter(current_items, fn(item) { item.id != item_id })
    |> todos_to_json()
  }

  wisp.redirect("/")
  |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
}

pub fn patch_toggle_todo(req: Request, ctx: Context, item_id: String) {
  let current_items = ctx.items

  let result = {
    use _ <- result.try(
      list.find(current_items, fn(item) { item.id == item_id }),
    )
    list.map(current_items, fn(item) {
      case item.id == item_id {
        True -> item.toggle(item)
        False -> item
      }
    })
    |> todos_to_json()
    |> Ok
  }

  case result {
    Ok(json_items) ->
      wisp.redirect("/")
      |> wisp.set_cookie(req, "items", json_items, wisp.PlainText, 60 * 60 * 24)
    Error(_) -> wisp.bad_request()
  }
}

fn items_decoder() -> fn(Dynamic) -> Result(List(ItemJson), List(DecodeError)) {
  dynamic.decode3(
    ItemJson,
    dynamic.field("id", dynamic.string),
    dynamic.field("title", dynamic.string),
    dynamic.field("completed", dynamic.bool),
  )
  |> dynamic.list()
}

fn create_items_from_json(items: List(ItemJson)) -> List(Item) {
  list.map(items, fn(item) {
    let ItemJson(id, title, completed) = item

    create(Some(id), title, completed)
  })
}

fn todos_to_json(items: List(Item)) -> String {
  "["
  <> items
  |> list.map(item_to_json)
  |> string.join(",")
  <> "]"
}

fn item_to_json(item: Item) -> String {
  json.object([
    #("id", json.string(item.id)),
    #("title", json.string(item.title)),
    #("completed", json.bool(item.status_to_bool(item.status))),
  ])
  |> json.to_string()
}
