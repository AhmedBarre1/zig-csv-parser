const std = @import("std");

const CsvField = struct {
    fields: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *CsvField) void {
        for (self.fields) |field| {
            self.allocator.free(field);
        }
        self.allocator.free(self.fields);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("../test.csv", .{});
    defer file.close();

    var buf_stream = std.io.bufferedReader(file.reader());
    var stream = buf_stream.reader();
    var buf: [4096]u8 = undefined;
    var line_count: usize = 0;

    std.debug.print("Headers: ", .{});

    if(try stream.readUntilDelimiterOrEof(&buf, '\n')) |header_line|{
        var header = try parseCsvLine(allocator, header_line);
        defer header.deinit();
        for(header.fields) |field|{
            std.debug.print("{s}, ", .{field});
        }
    }

    std.debug.print("\n", .{});
    while(try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var row = try parseCsvLine(allocator, line);
        for(row.fields) |field|{
            line_count+=1;
            std.debug.print("Row {d}: {s}\n", .{line_count, field});
        }
        defer row.deinit();
    }

}

fn parseCsvLine(allocator: std.mem.Allocator, line: []const u8) !CsvField {
    var fields = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (fields.items) |field| {
            allocator.free(field);
        } fields.deinit();
    }

    var field_start: usize = 0;
    var in_quotes = false;
    var i: usize = 0;

    while(i < line.len) {
        if(line[i] == '"'){
            in_quotes = !in_quotes;
            i += 1;
        } else if(line[i] == ',' and !in_quotes){
                const field = try allocator.dupe(u8, std.mem.trim(u8, line[field_start..i], " "));
                try fields.append(field);
                field_start = i+1;
        }
        i+= 1;
    }

    const field = try allocator.dupe(u8, std.mem.trim(u8, line[field_start..], " "));
    try fields.append(field);

    return CsvField{
        .fields = try fields.toOwnedSlice(),
        .allocator = allocator,
    };
}
