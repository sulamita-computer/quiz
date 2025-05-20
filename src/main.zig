const std = @import("std");
const zap = @import("zap");
const json = @import("json");

const eql = std.mem.eql;
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
    const file_name_list_html = std.mem.join(ALC, "<br />", file_name_list.items) catch unreachable;
    defer ALC.free(file_name_list_html);

    const html_data = std.mem.join(ALC, "", &[_][]const u8{
        "<html><body><h1>",
        file_name_list_html,
        "</h1></body></html>",
    }) catch unreachable;
    defer ALC.free(html_data);
    //////////

    r.sendBody(html_data) catch return;
}

const GameInfo = struct {
    title: []const u8,
    description: []const u8,
    quizes: []const struct {
        title: []const u8,
        description: []const u8,
    },
};

var file_name_list: std.ArrayList([]const u8) = undefined;
var game_data: std.ArrayList(GameInfo) = undefined;

pub fn main() !void {

    ///////// Prepare server
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
        .log = true,
        .max_clients = 100000,
    });
    try listener.listen();
    /////////

    ///////// Load games data
    file_name_list = std.ArrayList([]const u8).init(ALC);
    game_data = std.ArrayList(GameInfo).init(ALC);
    defer file_name_list.deinit();

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

            // Get only name of file without extname ".json"
            try file_name_list.append(std.mem.trimRight(u8, entry.name, ".json"));
        }
    }
    //////////

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
