extends SceneTree

const MOD_ID := "HeyboxCardStatsOverlay"
const PACK_ROOT := "res://pack_assets/%s" % MOD_ID
const BUNDLED_DATA_TARGET := "res://%s/data/cards.fallback.json" % MOD_ID

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Missing output .pck path.")
        quit(1)
        return

    var output_path := args[0]
    var packer := PCKPacker.new()
    var err := packer.pck_start(output_path)
    if err != OK:
        push_error("Failed to start pck build: %s" % err)
        quit(err)
        return

    err = packer.add_file("res://mod_manifest.json", ProjectSettings.globalize_path("res://mod_manifest.json"))
    if err != OK:
        push_error("Failed to add mod manifest: %s" % err)
        quit(err)
        return

    var files := {}
    _collect_files(ProjectSettings.globalize_path(PACK_ROOT), "res://%s" % MOD_ID, files)
    for target_path in files.keys():
        var source_path: String = files[target_path]
        err = packer.add_file(target_path, source_path)
        if err != OK:
            push_error("Failed to add %s -> %s (%s)" % [source_path, target_path, err])
            quit(err)
            return

    var bundled_data_source := _resolve_bundled_data_source()
    if bundled_data_source != "":
        err = packer.add_file(BUNDLED_DATA_TARGET, bundled_data_source)
        if err != OK:
            push_error("Failed to add bundled data %s -> %s (%s)" % [bundled_data_source, BUNDLED_DATA_TARGET, err])
            quit(err)
            return

    err = packer.flush()
    if err != OK:
        push_error("Failed to finalize pck: %s" % err)
        quit(err)
        return

    print("Built pck: %s" % output_path)
    quit(0)

func _collect_files(source_dir: String, target_dir: String, files: Dictionary) -> void:
    var dir := DirAccess.open(source_dir)
    if dir == null:
        push_error("Missing pack source dir: %s" % source_dir)
        quit(2)
        return

    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if name.begins_with("."):
            continue

        var source_path := source_dir.path_join(name)
        var target_path := target_dir.path_join(name)
        if dir.current_is_dir():
            _collect_files(source_path, target_path, files)
        else:
            files[target_path] = source_path
    dir.list_dir_end()

func _resolve_bundled_data_source() -> String:
    var candidates := [
        "res://data/cards.fallback.json",
        "res://data/cards.json",
        "res://sample_data/cards.sample.json"
    ]
    for candidate in candidates:
        if FileAccess.file_exists(candidate):
            return ProjectSettings.globalize_path(candidate)
    return ""
