//
// SwiftData.swift
// Copyright (c) 2015 Ryan Fowler
//
// SQLite3.swift
// Modified by alphaArgon on 2020/12/06.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Cocoa;
import SQLite3;

class SQLite {
    static func content(path: String, command: String) -> [[String: Any]] {
        var dbPointer: OpaquePointer? = nil;

        var status = sqlite3_open(path, &dbPointer);
        guard status == SQLITE_OK else {exit(0);}

        var dataView: OpaquePointer? = nil;
        sqlite3_prepare_v2(dbPointer!, command, -1, &dataView, nil)

        var columnCount: Int32 = 0;
        var next = true;
        var resultSet = [[String: Any]]();

        while next {
            status = sqlite3_step(dataView)
            if status == SQLITE_ROW {
                columnCount = sqlite3_column_count(dataView)
                var row = [String: Any]();
                
                for i in 0..<columnCount {
                    let columnName = String(cString: sqlite3_column_name(dataView, i));
                    var columnType = "";
                    switch sqlite3_column_type(dataView, i) {
                    case SQLITE_INTEGER:
                        columnType = "INTEGER"
                    case SQLITE_FLOAT:
                        columnType = "FLOAT"
                    case SQLITE_TEXT:
                        columnType = "TEXT"
                    case SQLITE3_TEXT:
                        columnType = "TEXT"
                    case SQLITE_BLOB:
                        columnType = "BLOB"
                    case SQLITE_NULL:
                        columnType = "NULL"
                    default:
                        columnType = "NULL"
                    }
                    if let columnValue = Self.getColumnValue(from: dataView!, at: i, as: columnType) {
                        row[columnName] = columnValue;
                    }
                }
                resultSet.append(row)
            } else {
                next = false
            }
        }
        
        sqlite3_finalize(dataView);
        return resultSet;
    }

    static private func getColumnValue(from statement: OpaquePointer, at index: Int32, as type: String) -> Any? {
        switch type {
            case "INT", "INTEGER", "TINYINT", "SMALLINT", "MEDIUMINT", "BIGINT", "UNSIGNED BIG INT", "INT2", "INT8":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil;
                }
                return Int(sqlite3_column_int(statement, index));
            case "CHARACTER(20)", "VARCHAR(255)", "VARYING CHARACTER(255)", "NCHAR(55)", "NATIVE CHARACTER", "NVARCHAR(100)", "TEXT", "CLOB":
                return String(cString: UnsafePointer<UInt8>(sqlite3_column_text(statement, index))!);
            case "BLOB", "NONE":
                if let blob = sqlite3_column_blob(statement, index) {
                    let size = sqlite3_column_bytes(statement, index)
                    return NSData(bytes: blob, length: Int(size));
                }
                return nil;
            case "REAL", "DOUBLE", "DOUBLE PRECISION", "FLOAT", "NUMERIC", "DECIMAL(10,5)":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil;
                }
                return Double(sqlite3_column_double(statement, index));
            case "BOOLEAN":
                if sqlite3_column_type(statement, index) == SQLITE_NULL {
                    return nil;
                }
                return sqlite3_column_int(statement, index) != 0;
            case "DATE", "DATETIME":
                let dateFormatter = DateFormatter();
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss";
                let string = String(cString: UnsafePointer<UInt8>(sqlite3_column_text(statement, index)));
                return dateFormatter.date(from: string);
            default:
                return nil;
        }
    }
}
