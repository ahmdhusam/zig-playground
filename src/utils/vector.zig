const std = @import("std");
const Allocator = std.mem.Allocator;
pub const VecErr = error{OutOfBounds};

pub fn Vec(comptime T: type) type {
    const State = struct {
        allocator: Allocator = undefined,
        ptr: [*]T,
        cap: usize = 0,
        postion: usize = 0,
        end: usize = 0,
    };

    return struct {
        state: State,
        const Self = @This();
        const grothBy = 2;

        pub fn init(alloc: Allocator) !*Self {
            return try Self.initWithCapacity(alloc, 4);
        }

        pub fn initWithLen(alloc: Allocator, length: usize) !*Self {
            const this = try Self.initWithCapacity(alloc, length);
            this.state.end = this.state.cap;

            const size = (@sizeOf(T) / @sizeOf(u8)) * this.state.cap;
            const asU8Slice = @as([*:0]u8, @ptrCast(this.state.ptr))[0..size];

            @memset(asU8Slice, 0);

            return this;
        }

        pub fn initWithCapacity(alloc: Allocator, capacity: usize) !*Self {
            const this: *Self = try alloc.create(Self);
            const ptr = try alloc.alloc(T, capacity);
            this.state.allocator = alloc;
            this.state.ptr = ptr.ptr;
            this.state.cap = ptr.len;
            this.state.postion = 0;
            this.state.end = 0;

            return this;
        }

        pub fn fromSlice(alloc: Allocator, slice: []const T) !*Self {
            var this = try initWithCapacity(alloc, slice.len);
            @memcpy(this.state.ptr[0..this.state.cap], slice);
            this.state.end = slice.len;

            return this;
        }

        pub fn deinit(this: *Self) void {
            defer this.state.allocator.destroy(this);
            defer {
                this.state.ptr = undefined;
                this.state.cap = undefined;
                this.state.end = 0;
                this.state.postion = 0;
            }

            this.state.allocator.free(this.state.ptr[0..this.state.cap]);
        }

        pub fn len(this: *Self) usize {
            return this.state.end - this.state.postion;
        }

        pub fn push(this: *Self, value: T) !void {
            if (this.state.end == this.state.cap) try this.growEnd();
            defer this.state.end += 1;
            this.state.ptr[this.state.end] = value;
        }

        pub fn unshift(this: *Self, value: T) !void {
            if (this.state.postion == 0) try this.growStart();
            this.state.postion -= 1;
            this.state.ptr[this.state.postion] = value;
        }

        pub fn pop(this: *Self) ?T {
            if (this.isEmpty()) return null;
            defer this.reduceMem() catch unreachable;

            this.state.end -= 1;
            return this.state.ptr[this.state.end];
        }

        pub fn shift(this: *Self) ?T {
            if (this.isEmpty()) return null;
            defer this.reduceMem() catch unreachable;

            defer this.state.postion += 1;
            return this.state.ptr[this.state.postion];
        }

        pub fn get(this: *Self, idx: isize) !T {
            const ptr = try this.at(idx);
            return ptr.*;
        }

        pub fn set(this: *Self, idx: isize, value: T) !void {
            const ptr = try this.at(idx);
            ptr.* = value;
        }

        pub fn asSlice(this: *Self) []T {
            return this.state.ptr[this.state.postion..this.state.end];
        }

        pub fn asOwnedSlice(this: *Self, allocator: Allocator) ![]T {
            const dest = try allocator.alloc(T, this.len());
            @memcpy(dest, this.asSlice());

            return dest;
        }

        pub fn isEmpty(this: *Self) bool {
            return this.len() == 0;
        }

        pub fn sort(this: *Self) void {
            const typeInfo = @typeInfo(T);
            const compNumber = struct {
                pub fn compNumber(context: void, a: T, b: T) bool {
                    return std.sort.asc(T)(context, a, b);
                }
            }.compNumber;

            switch (typeInfo) {
                inline .Float, .Int => {
                    std.mem.sort(T, this.asSlice(), {}, compNumber);
                },
                else => {},
            }
        }

        pub fn sortDesc(this: *Self) void {
            const typeInfo = @typeInfo(T);
            const compNumber = struct {
                pub fn compNumber(context: void, a: T, b: T) bool {
                    return std.sort.desc(T)(context, a, b);
                }
            }.compNumber;

            switch (typeInfo) {
                inline .Float, .Int => {
                    std.mem.sort(T, this.asSlice(), {}, compNumber);
                },
                else => {},
            }
        }

        pub fn print(this: *Self) void {
            std.debug.print("{any}\n\n", .{this.asSlice()});
        }

        fn at(this: *Self, idx: isize) VecErr!*T {
            if (this.isEmpty()) return VecErr.OutOfBounds;

            const i: usize = blk: {
                const length: isize = @intCast(this.len());
                const index: isize = if (idx < 0) idx + length else idx;

                if (index > (length - 1) or index < 0) return VecErr.OutOfBounds;
                break :blk @intCast(index);
            };

            return &this.state.ptr[this.state.postion + i];
        }

        fn growEnd(this: *Self) !void {
            const newCap = this.state.cap * grothBy;
            try this.resize(newCap, this.state.postion, this.state.end);
        }

        fn growStart(this: *Self) !void {
            const newCap = this.state.cap * grothBy;
            const defCap = newCap - this.state.cap;
            const newPostion = this.state.postion + defCap;
            const newLen = this.state.end + defCap;

            try this.resize(newCap, newPostion, newLen);
        }

        fn reduceMem(this: *Self) !void {
            const newCap = (this.state.cap / grothBy);
            if (!(this.len() < newCap)) return;

            const newPostion = 0;
            const newLen = this.len();

            try this.resize(newCap, newPostion, newLen);
        }

        fn resize(this: *Self, newCap: usize, postion: usize, length: usize) !void {
            const dest = try this.state.allocator.alloc(T, newCap);

            @memcpy(dest[postion..length], this.asSlice());

            this.state.allocator.free(this.state.ptr[0..this.state.cap]);

            this.state.ptr = dest.ptr;
            this.state.cap = dest.len;
            this.state.postion = postion;
            this.state.end = length;
        }
    };
}

test "Vec(T).push()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(list.len(), 0);

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expectEqual(list.len(), listSize);

    for (0..listSize) |value| {
        // list[0] == 0
        try testing.expect(try list.get(@intCast(value)) == @as(T, @intCast(value)));
    }

    try testing.expect(list.len() == listSize);
}

test "Vec(T).unshift()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(list.len(), 0);

    for (0..listSize) |value| {
        // it should to be [19, 18, 17, ..., 1, 0];
        try list.unshift(@intCast(value));
    }

    try testing.expectEqual(list.len(), listSize);

    for (0..listSize) |value| {
        // list[0] == ((20 - 1) - 0)
        try testing.expect(try list.get(@intCast(value)) == @as(T, @intCast((listSize - 1) - value)));
    }

    try testing.expect(list.len() == listSize);
}

test "Vec(T).pop()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [19, 18, 17, ..., 1, 0];
        try list.unshift(@intCast(value));
    }

    try testing.expect(list.len() == listSize);

    for (0..listSize) |value| {
        try testing.expectEqual(list.len(), listSize - value);

        // the list should to be [19, 18, 17, ..., 1]; && poped = 0; it should take the last element
        const poped = list.pop().?;
        try testing.expect(poped == @as(T, @intCast(value)));

        try testing.expectEqual(list.len(), (listSize - value - 1));
    }

    try testing.expect(list.pop() == null);

    try testing.expect(list.len() == 0);
}

test "Vec(T).shift()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len() == listSize);

    for (0..listSize) |value| {
        try testing.expectEqual(list.len(), listSize - value);

        // the list should to be [1, 2, ..., 18, 19] and shifted take the first item 0;
        const shifted = list.shift().?;
        try testing.expect(shifted == @as(T, @intCast(value)));

        try testing.expectEqual(list.len(), (listSize - value - 1));
    }

    try testing.expect(list.shift() == null);

    try testing.expect(list.len() == 0);
}

test "Vec(T).get()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len() == listSize);

    try testing.expectError(VecErr.OutOfBounds, list.get(listSize + 2));

    for (0..listSize) |index| {
        const value = @as(T, @intCast(index));

        try testing.expectEqual(list.len(), listSize);

        // it should return the value of index;
        try testing.expectEqual(list.get(@intCast(index)), value);

        try testing.expectEqual(list.len(), (listSize));
    }

    try testing.expectEqual(list.len(), (listSize));
}

test "Vec(T).set()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    const list = try Vec(T).init(testing.allocator);
    defer list.deinit();

    for (0..listSize) |value| {
        // it should to be [0, 1, 2, ..., 19];
        try list.push(@intCast(value));
    }

    try testing.expect(list.len() == listSize);

    for (0..listSize) |idx| {
        // It should multiply the elements by 2.
        const value = try list.get(@intCast(idx));
        try list.set(@intCast(idx), value * 2);
    }

    for (0..listSize) |index| {
        const value = @as(T, @intCast(index)) * 2;

        try testing.expectEqual(list.len(), listSize);

        // it should set the value of index;
        try testing.expectEqual(list.get(@intCast(index)), value);

        try testing.expectEqual(list.len(), (listSize));
    }

    try testing.expectEqual(list.len(), (listSize));
}

test "Vec(T).fromSlice()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    var arr: [20]T = undefined;

    for (0..listSize) |idx| {
        const value: T = @intCast(idx);
        arr[idx] = value;
    }

    const list = try Vec(T).fromSlice(testing.allocator, arr[0..]);
    defer list.deinit();

    try testing.expect(list.len() == listSize);

    for (0..listSize) |idx| {
        const value = try list.get(@intCast(idx));

        try testing.expectEqual(value, @intCast(idx));
    }

    try testing.expectEqual(list.len(), (listSize));
}

test "Vec(T).asSlice()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    var arr: [listSize]T = undefined;

    for (0..listSize) |idx| {
        const value: T = @intCast(idx);
        arr[idx] = value;
    }

    const list = try Vec(T).fromSlice(testing.allocator, arr[0..]);
    defer list.deinit();

    const listAsSlice = list.asSlice();

    try testing.expect(@TypeOf(list) != @TypeOf(listAsSlice));

    try testing.expectEqual(@TypeOf(listAsSlice), []T);

    try testing.expect(listAsSlice.len == listSize);

    for (0..listSize) |idx| {
        const value = listAsSlice[idx];

        try testing.expectEqual(value, @intCast(idx));
    }
}

test "Vec(T).asOwnedSlice()" {
    const testing = std.testing;
    const T = u8;
    const listSize: usize = 20;

    var arr: [listSize]T = undefined;

    for (0..listSize) |idx| {
        const value: T = @intCast(idx);
        arr[idx] = value;
    }

    const list = try Vec(T).fromSlice(testing.allocator, arr[0..]);
    defer list.deinit();

    const listAsSlice = list.asSlice();
    const listAsOwnedSlice = try list.asOwnedSlice(testing.allocator);
    defer testing.allocator.free(listAsOwnedSlice);

    try testing.expect(@TypeOf(list) != @TypeOf(listAsOwnedSlice));

    try testing.expectEqual(@TypeOf(listAsOwnedSlice), []T);

    try testing.expect(list.state.ptr == listAsSlice.ptr);
    try testing.expect(listAsSlice.ptr != listAsOwnedSlice.ptr);

    try testing.expect(listAsOwnedSlice.len == listSize);

    for (0..listSize) |idx| {
        try testing.expectEqual(listAsOwnedSlice[idx], listAsSlice[idx]);
    }

    for (0..listSize) |idx| {
        listAsOwnedSlice[idx] += 1;
    }

    for (0..listSize) |idx| {
        const listValue = try list.get(@intCast(idx));

        try testing.expect(listValue == listAsSlice[idx]);
        try testing.expect(listAsSlice[idx] != listAsOwnedSlice[idx]);
    }
}
