const std = @import("std");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;
const os = std.os;
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
    outer: while (true) {
        var response = try server.accept(.{ .allocator = allocator });
        defer response.deinit();

        while (response.reset() != .closing) {
            response.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };
            try requestHandler(&response, allocator);
        }
    }
}

fn requestHandler(response: *http.Server.Response, allocator: mem.Allocator) !void {
    log.info("{s}, {s}, {s}", .{ @tagName(response.request.method), @tagName(response.request.version), response.request.target });

    const user = UserModel{ .firstname = "Lahatra Anjara", .lastaname = "RAVELONARIVO", .username = "lahatra3", .registration_number = 3127373 };

    var userStr = ArrayList(u8).init(allocator);
    defer userStr.deinit();
    try json.stringify(user, .{}, userStr.writer());

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;

    if (mem.eql(u8, response.request.target, "/")) {
        try response.headers.append("Content-Type", "application/json");
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

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    log.info("Server is running on {s}:{d}", .{ server_addr, server_port });

    const address = net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    serve(&server, allocator) catch |err| {
        log.err("Server error: {}\n", .{err});

        if (@errorReturnTrace()) |trace| {
            debug.dumpStackTrace(trace.*);
        }
        os.exit(1);
    };
}
