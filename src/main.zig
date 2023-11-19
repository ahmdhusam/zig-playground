const std = @import("std");
const utils = @import("utils");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const vector = try utils.Vec(u8).init(alloc);
    defer vector.deinit();

    try vector.push(2);
    vector.print();

    const linkedList = try utils.LinkedList(i8).init(alloc);
    defer linkedList.deinit();

    try linkedList.push(1);
    linkedList.print();
}
