const std = @import("std");
const zap = @import("zap");
const json = @import("json");

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

    const game_titles = ALC.alloc([]const u8, game_data.items.len) catch unreachable;
    defer ALC.free(game_titles);

    for (game_titles, 0..) |*title, index| {
        title.* = game_data.items[index].title;
    }

    const game_titles_html = join(ALC, "<br />", game_titles) catch unreachable;
    defer ALC.free(game_titles_html);

    const html_data = join(ALC, "", &[_][]const u8{
        "<html><head><meta charset=\"UTF-8\"></head><body><h1>",
        game_titles_html,
        "</h1></body></html>",
    }) catch unreachable;
    defer ALC.free(html_data);
    //////////

    r.sendBody(html_data) catch return;
}

const GameInfo = struct {
    title: []const u8,
    description: []const u8,
    quizes: []const Question,
    allocator: std.mem.Allocator,

    const Question = struct {
        title: []const u8,
        description: []const u8,
        options: []const struct {
            label: []const u8,
            is_true: bool,
        },
    };

    // TODO: Need method deinit

    // TODO: Need error handlers
    pub fn initFromJSON(input: *json.JsonValue, allocator: std.mem.Allocator) !GameInfo {
        var res: GameInfo = undefined;
        res.allocator = allocator;

        const title_json = input.get("title").string();
        var title = try allocator.alloc(u8, title_json.len);
        copy(u8, title, title_json);
        res.title = title[0..];

        // res.description = input.get("description").string();
        // const quizes_number = input.get("quizes").array().len();
        // res.quizes = &(try allocator.alloc(Question, quizes_number));
        return res;
    }
};

var file_name_list: std.ArrayList([]const u8) = undefined;
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
    file_name_list = std.ArrayList([]const u8).init(ALC);
    game_data = std.ArrayList(GameInfo).init(ALC);
    defer file_name_list.deinit();
    defer game_data.deinit();

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

            try game_data.append(try GameInfo.initFromJSON(json_object, ALC));

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
