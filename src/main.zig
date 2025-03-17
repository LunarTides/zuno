const std = @import("std");
const builtin = @import("builtin");

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
    /// The first 3 bits signify the color, the last 4 signify the symbol.
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

        // Make sure the card has a color if the symbol requires it.
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

var running = true;
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

fn input(stdin: anytype) ![]const u8 {
    var buf: [4096]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |user_input| {
        return user_input;
    }

    return "";
}

pub fn main() !void {
    // Setup memory allocator.
    var gpa, const is_debug = gpa: {
        if (builtin.os.tag == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer _ = if (is_debug) debug_allocator.deinit();

    // Setup rng.
    const raw_seed: u128 = @bitCast(std.time.nanoTimestamp());
    const seed: u64 = @truncate(raw_seed);
    var random_number_generator = std.Random.DefaultPrng.init(seed);
    const rng = random_number_generator.random();

    // Setup stdout.
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Here are (3) randomly generated cards:\n", .{});

    const stdin = std.io.getStdIn().reader();

    // Setup players.
    var player1 = Player.init(&gpa);
    defer player1.deinit();

    // var player2 = Player.init(gpa);
    // defer player2.deinit();

    try player1.draw_card(&rng);
    try player1.draw_card(&rng);
    try player1.draw_card(&rng);

    while (running) {
        // Clear screen.
        try stdout.print("\x1b[2J\x1b[H", .{});

        // Print player's hand.
        for (player1.hand.items) |card| {
            const name = try card.name(&gpa);
            defer gpa.free(name);

            try stdout.print("{s}\n", .{name});
        }

        try stdout.print("\nWhich card would you like to play? (type 'exit' to exit) ", .{});

        const raw_user = try input(&stdin);

        // Remove the newline.
        const user = raw_user[0 .. raw_user.len - 1];

        if (std.ascii.eqlIgnoreCase(user, "exit")) {
            running = false;
        }
    }
}
