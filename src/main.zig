const std = @import("std");

const Color = enum(u7) {
    none = 0b0000000,
    red = 0b0010000,
    green = 0b0100000,
    blue = 0b0110000,
    yellow = 0b1000000,
};

const Symbol = enum(u7) {
    // Start at one since that makes sense.
    one = 0b0000001,
    two = 0b0000010,
    three = 0b0000011,
    four = 0b0000100,
    five = 0b0000101,
    six = 0b0000110,
    seven = 0b0000111,
    eight = 0b0001000,
    nine = 0b0001001,
    skip = 0b0001010,
    reverse = 0b0001011,
    plus_two = 0b0001100,
    wildcard = 0b0001101,
    plus_four = 0b0001110,
};

const Player = struct {
    hand: std.ArrayList(Card),

    fn init(gpa: *const std.mem.Allocator) Player {
        return Player{
            .hand = std.ArrayList(Card).init(gpa.*),
        };
    }

    fn deinit(self: *Player) void {
        self.hand.deinit();
    }

    fn draw_card(self: *Player, rng: *const std.Random) !void {
        const card = Card.random(rng);
        try self.hand.append(card);
    }
};

const Card = struct {
    bitmask: u7,

    fn init(bitmask: u7) Card {
        var color = get_color_from_bitmask(bitmask);
        const symbol = get_symbol_from_bitmask(bitmask);

        if (is_symbol_colorless(symbol)) {
            color = Color.none;
        } else if (color == Color.none) {
            // Default to red. This should be handled correctly in other functions.
            color = Color.red;
        }

        return Card{
            .bitmask = create_bitmask(color, symbol),
        };
    }

    fn random(rng: *const std.Random) Card {
        var color: Color = rng.enumValue(Color);
        const symbol: Symbol = rng.enumValue(Symbol);

        if (!is_symbol_colorless(symbol)) {
            while (color == Color.none) {
                color = rng.enumValue(Color);
            }
        }

        return init(create_bitmask(color, symbol));
    }

    fn name(self: Card, gpa: *const std.mem.Allocator) ![]u8 {
        const color = switch (get_color_from_bitmask(self.bitmask)) {
            Color.none => "",
            Color.red => "Red ",
            Color.green => "Green ",
            Color.blue => "Blue ",
            Color.yellow => "Yellow ",
        };

        const symbol = switch (get_symbol_from_bitmask(self.bitmask)) {
            Symbol.one => "1",
            Symbol.two => "2",
            Symbol.three => "3",
            Symbol.four => "4",
            Symbol.five => "5",
            Symbol.six => "6",
            Symbol.seven => "7",
            Symbol.eight => "8",
            Symbol.nine => "9",
            Symbol.skip => "Skip",
            Symbol.reverse => "Reverse",
            Symbol.plus_two => "+2",
            Symbol.wildcard => "Wildcard",
            Symbol.plus_four => "+4",
        };

        return try std.fmt.allocPrint(gpa.*, "{s}{s}", .{ color, symbol });
    }

    inline fn is_symbol_colorless(symbol: Symbol) bool {
        return symbol == Symbol.wildcard or symbol == Symbol.plus_four;
    }

    inline fn get_color_from_bitmask(bitmask: u7) Color {
        return @enumFromInt(bitmask & 0b1110000);
    }

    inline fn get_symbol_from_bitmask(bitmask: u7) Symbol {
        return @enumFromInt(bitmask & 0b0001111);
    }

    inline fn create_bitmask(color: Color, symbol: Symbol) u7 {
        return @intFromEnum(color) | @intFromEnum(symbol);
    }
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    // defer debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    const raw_seed: u128 = @bitCast(std.time.nanoTimestamp());
    const seed: u64 = @truncate(raw_seed);
    var random_number_generator = std.Random.DefaultPrng.init(seed);
    const rng = random_number_generator.random();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Here are (3) randomly generated cards:\n", .{});

    var player1 = Player.init(&gpa);
    defer player1.deinit();

    // var player2 = Player.init(gpa);
    // defer player2.deinit();

    try player1.draw_card(&rng);
    try player1.draw_card(&rng);
    try player1.draw_card(&rng);

    for (player1.hand.items) |card| {
        try stdout.print("{s}\n", .{try card.name(&gpa)});
    }
}
