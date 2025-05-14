const std = @import("std");
const zap = @import("zap");

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

var file_name_list: std.ArrayList([]const u8) = undefined;
const ALC = std.heap.c_allocator;

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
