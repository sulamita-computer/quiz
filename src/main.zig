const std = @import("std");
const zap = @import("zap");
const json = @import("json");

const Games = @import("./game_data.zig");
const GameInfo = Games.GameInfo;

const eql = std.mem.eql;
const join = std.mem.join;
const copy = std.mem.copyForwards;
const expect = std.testing.expect;

const ALC = std.heap.c_allocator;
// const TALC = std.testing.allocator;

fn on_request(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }

    // TODO: Should be normal error
    ////////// Formating data for HTML
    const game_labels = ALC.alloc([]const u8, game_data.items.len) catch unreachable;
    defer {
        for (game_labels) |label| {
            ALC.free(label); // defer afer join #1
        }
        ALC.free(game_labels);
    }

    for (game_labels, 0..) |*label, index| {
        const title = game_data.items[index].title;
        const description = game_data.items[index].description;
        label.* = join(ALC, "", &[_][]const u8{
            "<h1>",
            title,
            "</h1>",
            "<p>",
            description,
            "</p>",
        }) catch unreachable;
        // defer near game_labels #1
    }

    const game_labels_html = join(ALC, "<br />", game_labels) catch unreachable;
    defer ALC.free(game_labels_html);

    const html_data = join(ALC, "", &[_][]const u8{
        "<html><head><meta charset=\"UTF-8\"></head><body>",
        game_labels_html,
        "</body></html>",
    }) catch unreachable;
    defer ALC.free(html_data);
    //////////

    r.sendBody(html_data) catch return;
}

var game_data: std.ArrayList(GameInfo) = undefined;

pub fn main() !void {

    ///////// Prepare server
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
        // .log = true,
        .max_clients = 100000,
    });
    try listener.listen();
    /////////

    ///////// Load games data
    game_data = std.ArrayList(GameInfo).init(ALC);
    defer {
        for (game_data.items) |*game_info| {
            game_info.deinit();
        }
        game_data.deinit();
    }

    {
        var iter_dir = try std.fs.cwd().openDir(
            "games",
            .{ .iterate = true },
        );
        defer iter_dir.close();

        var iter = iter_dir.iterate();
        while (try iter.next()) |entry| {
            // TODO: Should be normal error
            if (entry.kind != .file) unreachable;

            const game_file = try iter_dir.openFile(entry.name, .{});
            defer game_file.close();

            const json_object = try json.parseFile(game_file, ALC);
            defer json_object.deinit(ALC);

            const game_info = try GameInfo.initFromJSON(json_object, ALC);

            try game_data.append(game_info);
        }
    }
    //////////

    // uncomment for testing deinit of GameInfo structures
    // return;

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1, // 1 worker enables sharing state between threads
    });
}

test "json parse" {
    const value = try json.parse(
        \\{
        \\  "title": "Опитування про Авраама з Біблії",
        \\  "description": "Це опитування перевіряє ваші знання про життя та події, пов'язані з Авраамом у Біблії.",
        \\  "quizes": [
        \\    {
        \\      "title": "Хто був батьком Авраама?",
        \\      "description": "Виберіть правильну відповідь про батька Авраама.",
        \\    }]}
    , ALC);
    defer value.deinit(ALC);
    const bazObj = value.get("quizes").get(0);

    // bazObj.print(null);
    try expect(eql(u8, bazObj.get("title").string(), "Хто був батьком Авраама?"));
}
