const std = @import("std");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const http = std.http;
const net = std.net;
const mem = std.mem;
const debug = std.debug;
const json = std.json;
const log = std.log.scoped(.server);
const UserModel = @import("struct/user.zig").UserModel;

const server_addr: []const u8 = "0.0.0.0";
const server_port: u16 = 3131;

fn serve(server: *http.Server, allocator: mem.Allocator) !void {
    _ = allocator;
    _ = server;
}

fn requestHandler(response: *http.Server.Response, allocator: mem.Allocator) !void {
    log.info("{s}, {s}, {s}", .{ @tagName(response.request.method), @tagName(response.request.version), response.request.target });

    const user = UserModel{ .firstname = "Lahatra Anjara", .lastaname = "RAVELONARIVO", .username = "lahatra3", .uuid = 12354 };

    var userStr = ArrayList(u8).init(allocator);
    defer userStr.deinit();
    try json.stringify(user, .{}, userStr.writer());

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }
    response.transfer_encoding = .chunked;

    if (mem.eql(u8, response.request.target, "/")) {
        try response.headers.append("content-type", "application/json");
        try response.do();

        if (response.request.method != .HEAD) {
            try response.writeAll(userStr.items);
            try response.finish();
        }
    } else {
        response.status = .not_found;
        try response.do();
        try response.writeAll("404, not found");
        try response.finish();
    }
}

pub fn main() !void {}
