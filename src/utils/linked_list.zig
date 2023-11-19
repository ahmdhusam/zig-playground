const std = @import("std");
const Allocator = std.mem.Allocator;
const IdxErr = error{OutOfBounds};

pub fn LinkedList(comptime T: type) type {
    return struct {
        const Node = struct {
            value: T,
            next: ?*Node = null,

            fn init(alloc: Allocator, value: T) !*Node {
                const node = try alloc.create(Node);
                node.value = value;
                node.next = null;
                return node;
            }

            fn deinit(this: *@This(), alloc: Allocator) void {
                alloc.destroy(this);
            }
        };
        const Self = @This();

        head: ?*Node = null,
        tail: ?*Node = null,
        len: usize = 0,
        allocator: Allocator,

        pub fn init(alloc: Allocator) !*Self {
            const this = try alloc.create(Self);
            this.allocator = alloc;
            this.len = 0;
            this.head = null;
            this.tail = null;

            return this;
        }

        pub fn deinit(this: *Self) void {
            defer this.allocator.destroy(this);

            if (this.isEmpty()) return;

            defer {
                this.head = null;
                this.tail = null;
                this.len = 0;
            }
            while (this.shift()) |_| {}
        }

        pub fn isEmpty(this: *Self) bool {
            return this.len == 0;
        }

        pub fn push(this: *Self, value: T) !void {
            const node = try Node.init(this.allocator, value);
            defer {
                this.len += 1;
                this.tail = node;
            }

            if (this.isEmpty()) {
                this.head = node;
                return;
            }

            this.tail.?.next = node;
        }

        pub fn unshift(this: *Self, value: T) !void {
            const node = try Node.init(this.allocator, value);

            defer {
                this.len += 1;
                this.head = node;
            }

            if (this.isEmpty()) {
                this.tail = node;
                return;
            }

            node.next = this.head;
        }

        pub fn pop(this: *Self) ?T {
            const tail = this.tail orelse return null;
            defer {
                this.len -= 1;
                tail.deinit(this.allocator);
            }

            const tailParent = this.at(-2) catch {
                this.head = null;
                this.tail = null;
                return tail.value;
            };
            tailParent.next = null;
            this.tail = tailParent;

            return tail.value;
        }

        pub fn shift(this: *Self) ?T {
            const head = this.head orelse return null;

            defer {
                this.len -= 1;
                head.deinit(this.allocator);
            }

            if (head.next) |next| {
                this.head = next;
            } else {
                this.tail = null;
                this.head = null;
            }

            return head.value;
        }

        pub fn remove(this: *Self, idx: isize) !T {
            const node = try this.at(idx);

            if (this.head == node) {
                return this.shift().?;
            }

            if (this.tail == node) {
                return this.pop().?;
            }

            defer {
                this.len -= 1;
                node.deinit(this.allocator);
            }

            const nodeParent = this.at(idx - 1) catch unreachable;

            nodeParent.next = node.next;
            return node.value;
        }

        pub fn get(this: *Self, idx: isize) !T {
            const node = try this.at(idx);
            return node.value;
        }

        pub fn set(this: *Self, idx: isize, value: T) !void {
            const node = try this.at(idx);
            node.value = value;
        }

        fn at(this: *Self, idx: isize) IdxErr!*Node {
            if (this.isEmpty()) return IdxErr.OutOfBounds;

            const i: usize = blk: {
                const len: isize = @intCast(this.len);
                const index: isize = if (idx < 0) idx + len else idx;

                if (index > (len - 1) or index < 0) return IdxErr.OutOfBounds;

                break :blk @intCast(index);
            };

            var head = this.head;
            for (0..i) |_| {
                head = head.?.next;
            }

            return head.?;
        }

        pub fn print(this: *Self) void {
            var head = this.head;
            std.debug.print("[", .{});
            while (head) |n| : (head = n.next) {
                std.debug.print("{}", .{n.value});
                if (head != this.tail) std.debug.print(", ", .{});
            }
            std.debug.print("]\n", .{});
        }
    };
}

test "LinkedList(T).push()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(list.len, 0);

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expectEqual(list.len, listSize);

    for (0..listSize) |value| {
        // list[0] == 0
        try testing.expect(try list.get(@intCast(value)) == @as(T, @intCast(value)));
    }

    try testing.expect(list.len == listSize);
}

test "LinkedList(T).unshift()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(list.len, 0);

    for (0..listSize) |value| {
        // it should to be [19, 18, 17, ..., 1, 0];
        try list.unshift(@intCast(value));
    }

    try testing.expectEqual(list.len, listSize);

    for (0..listSize) |value| {
        // list[0] == ((20 - 1) - 0)
        try testing.expect(try list.get(@intCast(value)) == @as(T, @intCast((listSize - 1) - value)));
    }

    try testing.expect(list.len == listSize);
}

test "LinkedList(T).pop()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [19, 18, 17, ..., 1, 0];
        try list.unshift(@intCast(value));
    }

    try testing.expect(list.len == listSize);

    for (0..listSize) |value| {
        try testing.expectEqual(list.len, listSize - value);

        // the list should to be [19, 18, 17, ..., 1]; && poped = 0; it should take the last element
        const poped = list.pop().?;
        try testing.expect(poped == @as(T, @intCast(value)));

        try testing.expectEqual(list.len, (listSize - value - 1));
    }

    try testing.expect(list.pop() == null);

    try testing.expect(list.len == 0);
}

test "LinkedList(T).shift()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len == listSize);

    for (0..listSize) |value| {
        try testing.expectEqual(list.len, listSize - value);

        // the list should to be [1, 2, ..., 18, 19] and shifted take the first item 0;
        const shifted = list.shift().?;
        try testing.expect(shifted == @as(T, @intCast(value)));

        try testing.expectEqual(list.len, (listSize - value - 1));
    }

    try testing.expect(list.shift() == null);

    try testing.expect(list.len == 0);
}

test "LinkedList(T).get()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len == listSize);

    try testing.expectError(IdxErr.OutOfBounds, list.get(listSize + 2));

    for (0..listSize) |index| {
        const value = @as(T, @intCast(index));

        try testing.expectEqual(list.len, listSize);

        // it should return the value of index;
        try testing.expectEqual(list.get(@intCast(index)), value);

        try testing.expectEqual(list.len, (listSize));
    }

    try testing.expectEqual(list.len, (listSize));
}

test "LinkedList(T).set()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len == listSize);

    for (0..listSize) |idx| {
        // It should multiply the elements by 2.
        const value = try list.get(@intCast(idx));
        try list.set(@intCast(idx), value * 2);
    }

    for (0..listSize) |index| {
        const value = @as(T, @intCast(index)) * 2;

        try testing.expectEqual(list.len, listSize);

        // it should set the value of index;
        try testing.expectEqual(list.get(@intCast(index)), value);

        try testing.expectEqual(list.len, (listSize));
    }

    try testing.expectEqual(list.len, (listSize));
}

test "LinkedList(T).remove()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try LinkedList(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len == listSize);

    try testing.expectEqual(try list.get(5), 5);

    try testing.expect(list.len == listSize);

    try testing.expectEqual(try list.remove(5), 5);

    try testing.expect(list.len == (listSize - 1));

    try testing.expectEqual(try list.get(5), 6);
}
