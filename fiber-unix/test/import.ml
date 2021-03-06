include Stdune
include Fiber.O
include Dyn.Encoder

let printf = Printf.printf

let print pp = Format.printf "%a@." Pp.render_ignore_tags pp

let print_dyn dyn = print (Dyn.pp dyn)

module Scheduler : sig
  exception Never

  val yield : unit -> unit Fiber.t

  val run : 'a Fiber.t -> 'a
end = struct
  let suspended = Queue.create ()

  let yield () =
    let ivar = Fiber.Ivar.create () in
    Queue.push suspended ivar;
    Fiber.Ivar.read ivar

  let rec restart_suspended () =
    if Queue.is_empty suspended then
      Fiber.return ()
    else
      let* () = Fiber.Ivar.fill (Queue.pop_exn suspended) () in
      restart_suspended ()

  exception Never

  let run t =
    match
      Fiber.run
        (let* result = Fiber.fork (fun () -> t) in
         let* () = restart_suspended () in
         Fiber.Ivar.peek result)
    with
    | None
    | Some None ->
      raise Never
    | Some (Some x) -> x
end

let test ?(expect_never = false) to_dyn f =
  let never_raised = ref false in
  ( try Scheduler.run f |> to_dyn |> print_dyn
    with Scheduler.Never -> never_raised := true );
  match (!never_raised, expect_never) with
  | false, false ->
    (* We don't raise in this case b/c we assume something else is being tested *)
    ()
  | true, true -> print_endline "[PASS] Never raised as expected"
  | false, true ->
    print_endline "[FAIL] expected Never to be raised but it wasn't"
  | true, false -> print_endline "[FAIL] unexpected Never raised"
