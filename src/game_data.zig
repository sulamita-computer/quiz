const std = @import("std");
const json = @import("json");

const copy = std.mem.copyForwards;

pub const GameInfo = struct {
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

    pub fn deinit(self: *GameInfo) void {
        self.allocator.free(self.title);
        self.allocator.free(self.description);
    }

    // TODO: Need error handlers
    pub fn initFromJSON(input: *json.JsonValue, allocator: std.mem.Allocator) !GameInfo {
        var res: GameInfo = undefined;
        res.allocator = allocator;

        const title_json = input.get("title").string();
        var title = try allocator.alloc(u8, title_json.len);
        copy(u8, title, title_json);
        res.title = title[0..];

        const description_json = input.get("title").string();
        var description = try allocator.alloc(u8, title_json.len);
        copy(u8, description, description_json);
        res.description = description[0..];

        return res;
    }
};
