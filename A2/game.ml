#require "yojson"
#require "str"
open Yojson
(*Record for an exit*)
type exit_rec =
  {
    direction     : string;
    room          : string;
  }
(*Record for a room*)
type room_rec =
  {
    id            : string;
    description   : string;
    items         : string list;
    points        : int;
    exits         : exit_rec list;
    treasures     : string list;
  }
(*Record for an item*)
type item_rec=
  {
    id            : string;
    description   : string;
    points        : int;
  }
(*Helper function for parsing an "exit" json object*)
let parse_exit e =
  let open Yojson.Basic.Util in
  {direction    = e |> (member "direction") |> to_string;
   room         = e |> (member "room") |> to_string;}
(*Helper function for parsing an array of "exit" json object*)
let rec parse_exits jsonExits =
  match jsonExits with
  | [] -> []
  | hd::tl -> parse_exit hd :: parse_exits tl
(*Helper function for parsing an item json object*)
let parse_item i =
  let open Yojson.Basic.Util in
  {id           = to_string (member "id" i);
   description  = to_string (member "description" i);
   points       = to_int (member "points" i);}
(*Helper function for parsing a room json object*)
let parse_room r =
  let open Yojson.Basic.Util in
  {id           = to_string (member "id" r);
   description  = to_string (member "description" r);
   items        = filter_string (filter_member "items" [r]);
   points       = to_int (member "points" r);
   exits        = parse_exits (flatten (filter_member "exits" [r]));
   treasures    = filter_string (filter_member "treasure" [r]);}
(*Helper function for parsing an array of "item" json object*)
let rec parse_items jsonItems =
  match jsonItems with
  | [] -> []
  | hd::tl -> parse_item hd :: parse_items tl
(*Helper function for parsing an array "room" json object*)
let rec parse_rooms jsonRooms =
  match jsonRooms with
  | [] -> []
  | hd::tl -> parse_room hd :: parse_rooms tl
(*Function extracts an array of all "room" json objects*)
let extract_rooms (t : Yojson.Basic.json) : room_rec list =
  let open Yojson.Basic.Util in
  [t]
  |> filter_member "rooms"
  |> flatten
  |> parse_rooms

let extract_items (t : Yojson.Basic.json) : item_rec list =
  let open Yojson.Basic.Util in
  [t]
  |> filter_member "items"
  |> flatten
  |> parse_items

let extract_start_room (t: Yojson.Basic.json) : string =
  let open Yojson.Basic.Util in
  [t]
  |> filter_member "start_room"
  |> List.hd
  |> to_string

let extract_start_items (t: Yojson.Basic.json) : string list =
  let open Yojson.Basic.Util in
  [t]
  |> filter_member "start_items"
  |> flatten
  |> filter_string

let t = Yojson.Basic.from_file "minimal.json"
let items = extract_items t
let rooms = extract_rooms t
let start_room = extract_start_room t
let start_items = extract_start_items t

let rec main_game_loop (visited_rooms : string list)
  (item_locations : (string * string) list) (current_room_id : string)
  (inventory : string list) (points : int) (turns : int) =
  (*Read the input*)
  let input = String.lowercase (read_line ()) in
  (*Tokenize the string for pattern matching*)
  let input_split = Str.bounded_split (Str.regexp "[ \t]+") input 2 in
  (*Get the room record for the current room*)
  let current_room =
    let rec get_cur_room (r:room_rec list) r_id=
      match r with
      | [] -> failwith "Room error exception"
      | hd::tl -> if hd.id = r_id then hd else get_cur_room tl r_id in
    get_cur_room rooms current_room_id in
  (*Check whether the room with id = r_id has been visited*)
  let visited r_id=
    if List.filter (fun x -> x = r_id) visited_rooms <> []
    then true else false in
  (*Helper function to return the exit record for a movement direction
   *Returns a list. The list is empty for an invalid direction*)
  let get_exit move_input =
    List.filter (fun x -> x.direction = move_input) current_room.exits in
  (*Pattern match the input to figure out what the user wants*)
  let decode_input command =
    match command with
    (*quit command*)
    | "quit"::tl -> Printf.printf "Quitting game\n"
    (*look command*)
    | "look"::tl -> Printf.printf "%s\n" current_room.description;
      main_game_loop visited_rooms item_locations
      current_room_id inventory 0 0
    (*inventory command*)
    | hd::tl when hd = "inventory" || hd = "inv" ->
      Printf.printf "Your inventory contains:\n";
      List.iter (fun x -> Printf.printf "%s\n" x) inventory;
      main_game_loop visited_rooms item_locations
      current_room_id inventory 0 0
    (*item commands*)
    | hd::tl when hd = "take" || hd = "drop" ->
      main_game_loop visited_rooms item_locations
      current_room_id inventory 0 0
    (*movement commands (using go)*)
    | hd::tl when hd = "go" -> let exit = get_exit (List.hd tl) in
      if exit <> [] then
      main_game_loop
      (if visited (List.hd exit).room
        then visited_rooms else (List.hd exit).room::visited_rooms)
      item_locations
      (List.hd exit).room inventory 0 0
    (*single word movement commands*)
    | hd::[] when get_exit hd <> []-> Printf.printf "%s\n" hd;
      main_game_loop visited_rooms item_locations
      current_room_id inventory 0 0
    | _ -> Printf.printf "Sorry I don't understand that\n";
      main_game_loop visited_rooms item_locations
      current_room_id inventory 0 0 in
  decode_input input_split in

main_game_loop [] [] start_room start_items 0 0