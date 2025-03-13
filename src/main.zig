const std = @import("std");

const Color = enum {
    none,
    red,
    green,
    blue,
    yellow,
};

const Type = enum {
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    skip,
    reverse,
    plus_two,
    wildcard,
    plus_four,
};

const Player = struct {
    hand: std.ArrayList(Card),

    fn init(gpa: std.mem.Allocator) Player {
        return Player{
            .hand = std.ArrayList(Card).init(gpa),
        };
    }

    fn deinit(self: *Player) void {
        self.hand.deinit();
    }

    fn draw_card(self: *Player) !void {
        const card = Card.random();
        try self.hand.append(card);
    }
};

const Card = struct {
    color: Color,
    type: Type,

    fn init(color: Color, @"type": Type) Card {
        var _color = color;
        const _type = @"type";

        if (is_type_colorless(_type)) {
            _color = Color.none;
        } else if (color == Color.none) {
            // Default to red. This should be handled correctly in other functions.
            _color = Color.red;
        }

        return Card{
            .color = _color,
            .type = _type,
        };
    }

    fn random() Card {
        const raw_seed: u128 = @bitCast(std.time.nanoTimestamp());
        const seed: u64 = @truncate(raw_seed);
        var random_number_generator = std.Random.DefaultPrng.init(seed);
        const rng = random_number_generator.random();

        var color: Color = @enumFromInt(rng.uintAtMost(u8, 4));
        const @"type": Type = @enumFromInt(rng.uintAtMost(u8, 13));

        if (!is_type_colorless(@"type") and color == Color.none) {
            color = @enumFromInt(rng.uintAtMost(u8, 3) + 1);
        }

        return init(color, @"type");
    }

    fn name(self: Card, gpa: std.mem.Allocator) ![]u8 {
        const color = switch (self.color) {
            Color.none => "",
            Color.red => "Red ",
            Color.green => "Green ",
            Color.blue => "Blue ",
            Color.yellow => "Yellow ",
        };

        const @"type" = switch (self.type) {
            Type.one => "1",
            Type.two => "2",
            Type.three => "3",
            Type.four => "4",
            Type.five => "5",
            Type.six => "6",
            Type.seven => "7",
            Type.eight => "8",
            Type.nine => "9",
            Type.skip => "Skip",
            Type.reverse => "Reverse",
            Type.plus_two => "+2",
            Type.wildcard => "Wildcard",
            Type.plus_four => "+4",
        };

        return try std.fmt.allocPrint(gpa, "{s}{s}", .{ color, @"type" });
    }

    fn is_type_colorless(@"type": Type) bool {
        return @"type" == Type.wildcard or @"type" == Type.plus_four;
    }
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    // defer debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{"world"});

    var player1 = Player.init(gpa);
    defer player1.deinit();

    // var player2 = Player.init(gpa);
    // defer player2.deinit();

    try player1.draw_card();
    try player1.draw_card();
    try player1.draw_card();

    for (player1.hand.items) |card| {
        try stdout.print("{s}\n", .{try card.name(gpa)});
    }
}
