// DictusCore/Sources/DictusCore/LoggedError.swift
// The part of a foreign error the persistent log may keep (#939).
import Foundation

/// An error reduced to its domain and code, and those of the errors under it.
///
/// WHY not `localizedDescription` or `"\(error)"`: the log now leaves the device
/// through the feedback form, and the text of WhisperKit, FluidAudio, Core ML and
/// Cocoa file errors can name files on the device (a model path, `NSFilePath` in
/// the userInfo), which on a simulator includes the developer's user name. The
/// domain and code identify the failure without carrying any of that.
public enum LoggedError {
    /// `domain=NSCocoaErrorDomain code=4 underlying=NSPOSIXErrorDomain:2`. A Swift
    /// error bridges to its type name as the domain and its case index as the code.
    public static func domainAndCode(_ error: Error) -> String {
        var current = error as NSError
        var text = "domain=\(current.domain) code=\(current.code)"
        // Bounded: a userInfo chain is not guaranteed to end.
        for _ in 0..<3 {
            guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { break }
            text += " underlying=\(underlying.domain):\(underlying.code)"
            current = underlying
        }
        return text
    }
}
