//
//  SourceEditorCommand.swift
//  XcodeSourceEditorPlaceholderExtension
//
//  Created by Konstantinos Kontos on 22/11/2016.
//  Copyright © 2016 K. K. Handmade Apps Ltd. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
        
        if invocation.commandIdentifier == "handyXcode.Insert" {
            
            
            for i in 0 ..< invocation.buffer.selections.count {
                let sourceCodeRange = invocation.buffer.selections[i] as! XCSourceTextRange
                
                if sourceCodeRange.start.column == sourceCodeRange.end.column && sourceCodeRange.start.line == sourceCodeRange.end.line {
                    processInsertCommand(selection: sourceCodeRange, invocation: invocation, selectionIndex: i)
                } else {
                    processReplaceCommand(selection: sourceCodeRange, invocation: invocation, selectionIndex: i)
                }
            }
            
        }
        
        
        if invocation.commandIdentifier == "handyXcode.Insert.MultiLineComment" {
            
            for i in 0 ..< invocation.buffer.selections.count {
                let sourceCodeRange = invocation.buffer.selections[i] as! XCSourceTextRange
                
                if (sourceCodeRange.start.column == sourceCodeRange.end.column && sourceCodeRange.start.line == sourceCodeRange.end.line) == false {
                    processMultiLineCommentCommand(selection: sourceCodeRange, invocation: invocation, selectionIndex: i)
                }
                
            }
            
            
        }
        
        
        if invocation.commandIdentifier == "handyXcode.Insert.JSONLint" {
            jsonLint(invocation: invocation)
        }

        
        completionHandler(nil)
    }
    
    func jsonLint(invocation: XCSourceEditorCommandInvocation) {
        let jsonStr = invocation.buffer.completeBuffer
        
        if let jsonData = jsonStr.data(using: .utf8) {
            
            do {
                _ = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
            } catch (let error as NSError) {
                
                var errorStr = error.debugDescription
                errorStr += "\n\n"
                
                invocation.buffer.lines.insert(errorStr, at: 0)
            }
            
        }
        
    }
    
    func processMultiLineCommentCommand(selection: XCSourceTextRange, invocation: XCSourceEditorCommandInvocation, selectionIndex: Int) {
        let sourceCodeRange = selection

        // Adjust range for select-all command
        if sourceCodeRange.end.line > invocation.buffer.lines.count - 1 {
            sourceCodeRange.end.line = invocation.buffer.lines.count - 1
            sourceCodeRange.end.column = (invocation.buffer.lines.lastObject as! String).count - 1
        }
        
        
        var commentedTextLines = [String]()
        
        // Check for existing comment block
        
        var checkingCharSet = CharacterSet.controlCharacters
        checkingCharSet = checkingCharSet.union(CharacterSet.whitespacesAndNewlines)
        
        let firstLine = (invocation.buffer.lines[sourceCodeRange.start.line] as! String).trimmingCharacters(in: checkingCharSet)
        let endingLine = (invocation.buffer.lines[sourceCodeRange.end.line] as! String).trimmingCharacters(in: checkingCharSet)
        
        if firstLine.starts(with: "/*") && endingLine.starts(with: "*/") {
            
            for lineIndex in sourceCodeRange.start.line.advanced(by: 1) ... sourceCodeRange.end.line.advanced(by: -1) {
                commentedTextLines.append(invocation.buffer.lines[lineIndex] as! String)
            }
            
        } else {
            commentedTextLines.append("/*")
            
            for lineIndex in sourceCodeRange.start.line ... sourceCodeRange.end.line {
                commentedTextLines.append(invocation.buffer.lines[lineIndex] as! String)
            }
            
            commentedTextLines.append("*/")
        }
        
        invocation.buffer.lines.removeObjects(in: NSMakeRange(sourceCodeRange.start.line, sourceCodeRange.end.line - sourceCodeRange.start.line + 1))
        
        invocation.buffer.lines.insert(commentedTextLines, at: IndexSet(integersIn: (sourceCodeRange.start.line ..< (sourceCodeRange.start.line + commentedTextLines.count))))
        
        // Nullify selection
        invocation.buffer.selections[selectionIndex] = XCSourceTextRange(start: sourceCodeRange.start,
                                                                         end: sourceCodeRange.start)
    }
    
    func processInsertCommand(selection: XCSourceTextRange, invocation: XCSourceEditorCommandInvocation, selectionIndex: Int) {
        let sourceCodeRange = selection
        
        var startLine = ""
        
        if sourceCodeRange.start.column == 0 {
            invocation.buffer.lines.add("<# code #>")
        } else {
            startLine = invocation.buffer.lines[sourceCodeRange.start.line] as! String
            
            let startIndex = startLine.index(startLine.startIndex, offsetBy: sourceCodeRange.start.column)
            
            startLine.insert(contentsOf: "<# code #>", at: startIndex)
            
            invocation.buffer.lines[sourceCodeRange.start.line] = startLine
        }
        
    }
    
    func processReplaceCommand(selection: XCSourceTextRange, invocation: XCSourceEditorCommandInvocation, selectionIndex: Int) {
        let sourceCodeRange = selection
        
        if sourceCodeRange.start.line == sourceCodeRange.end.line {
            var startLine = invocation.buffer.lines[sourceCodeRange.start.line] as! String
            
            let startIndex = startLine.index(startLine.startIndex, offsetBy: sourceCodeRange.start.column)
            let endIndex = startLine.index(startLine.startIndex, offsetBy: sourceCodeRange.end.column)
            
            let stringRange = Range<String.Index>(uncheckedBounds: (lower: startIndex, upper: endIndex))
            
            startLine.replaceSubrange(stringRange, with: "<# code #>")
            
            invocation.buffer.lines[sourceCodeRange.start.line] = startLine
            
            // Nullify selection
            invocation.buffer.selections[selectionIndex] = XCSourceTextRange(start: sourceCodeRange.start,
                                                                             end: sourceCodeRange.start)
        } else {
            
            // Adjust range for select-all command
            if sourceCodeRange.end.line > invocation.buffer.lines.count - 1 {
                sourceCodeRange.end.line = invocation.buffer.lines.count - 1
                sourceCodeRange.end.column = (invocation.buffer.lines.lastObject as! String).count - 1
            }
            
            // Get head of replacement
            let startLine = invocation.buffer.lines[sourceCodeRange.start.line] as! String
            
            var editStart = startLine.startIndex
            var editEnd = startLine.index(startLine.startIndex, offsetBy: sourceCodeRange.start.column)
            
//            let substringA = startLine.substring(with: Range<String.Index>(uncheckedBounds: (lower: editStart, upper: editEnd)))
            let substringA = startLine[editStart..<editEnd]
            
            // Get tail of replacement
            var endLine = ""
            if invocation.buffer.lines.count == sourceCodeRange.end.line {
                invocation.buffer.lines.removeAllObjects()
                
                invocation.buffer.lines.add("<# code #>")
            } else {
                endLine = invocation.buffer.lines[sourceCodeRange.end.line] as! String
                
                editStart = endLine.index(endLine.startIndex, offsetBy: sourceCodeRange.end.column)
                editEnd = endLine.endIndex
                
//                let substringB = endLine.substring(with: Range<String.Index>(uncheckedBounds: (lower: editStart, upper: editEnd)))
                let substringB = endLine[editStart..<editEnd]
                
                // replace text
                let replacementString = "\(substringA)<# code #>\(substringB)"
                
                invocation.buffer.lines.removeObjects(in: NSMakeRange(sourceCodeRange.start.line, sourceCodeRange.end.line - sourceCodeRange.start.line + 1))
                
                invocation.buffer.lines.insert(replacementString, at: sourceCodeRange.start.line)
            }
            
            
            // Nullify selection
            invocation.buffer.selections[selectionIndex] = XCSourceTextRange(start: sourceCodeRange.start,
                                                                             end: sourceCodeRange.start)
        }
        
    }
    
    
}
