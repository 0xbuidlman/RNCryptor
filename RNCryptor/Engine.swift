//
//  Cryptor.swift
//  RNCryptor
//
//  Created by Rob Napier on 6/27/15.
//  Copyright © 2015 Rob Napier. All rights reserved.
//

import Foundation
import CommonCrypto

public enum CryptorOperation: CCOperation {
    case Encrypt = 0 // CCOperation(kCCEncrypt)
    case Decrypt = 1 // CCOperation(kCCDecrypt)
}

internal final class Engine: CryptorType {
    private let cryptor: CCCryptorRef
    private var buffer = [UInt8]()

    init(operation: CryptorOperation, key: [UInt8], iv: [UInt8]) {
        var cryptorOut = CCCryptorRef()
        let result = CCCryptorCreate(
            operation.rawValue,
            CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding),
            key, key.count,
            iv,
            &cryptorOut
        )
        self.cryptor = cryptorOut

        // It is a programming error to create us with illegal values
        // This is an internal class, so we can constrain what is sent to us.
        // If this is ever made public, it should throw instead of asserting.
        assert(result == CCCryptorStatus(kCCSuccess))
    }

    deinit {
        if self.cryptor != CCCryptorRef() {
            CCCryptorRelease(self.cryptor)
        }
    }

    func sizeBufferForDataOfLength(length: Int) -> Int {
        let size = CCCryptorGetOutputLength(cryptor, length, true)
        let delta = size - buffer.count
        if delta > 0 {
            buffer += [UInt8](count: delta, repeatedValue:0)
        }
        return size
    }

    func update(data: UnsafeBufferPointer<UInt8>) throws -> [UInt8] {
        let outputLength = sizeBufferForDataOfLength(data.count)
        var dataOutMoved: Int = 0

        var result: CCCryptorStatus = CCCryptorStatus(kCCUnimplemented)

        result = CCCryptorUpdate(
            self.cryptor,
            data.baseAddress, data.count,
            &buffer, outputLength,
            &dataOutMoved)

        // The only error returned by CCCryptorUpdate is kCCBufferTooSmall, which would be a programming error
        assert(result == CCCryptorStatus(kCCSuccess))

        buffer.removeRange(dataOutMoved..<buffer.endIndex)
        return buffer
    }

    func final() throws -> [UInt8] {
        let outputLength = sizeBufferForDataOfLength(0)
        var dataOutMoved: Int = 0

        let result = CCCryptorFinal(
            self.cryptor,
            &buffer, outputLength,
            &dataOutMoved
        )
        
        guard result == CCCryptorStatus(kCCSuccess) else {
            throw NSError(domain: CCErrorDomain, code: Int(result), userInfo: nil)
        }

        buffer.removeRange(dataOutMoved..<buffer.endIndex)
        return buffer
    }
}