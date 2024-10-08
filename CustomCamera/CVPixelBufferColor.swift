//
//  CVPixelBufferColor.swift
//  ARPaint
//
//  Created by Abe White on 9/13/18.
//  Copyright © 2018 Hedonic Software. All rights reserved.
//

import Accelerate
import UIKit

private var _conversionInfoYpCbCrToARGB: vImage_YpCbCrToARGB? = {
    var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 235, YpMin: 16, CbCrMax: 240, CbCrMin: 16)
    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
    guard vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!, &pixelRange, &infoYpCbCrToARGB, kvImage422CbYpCrYp8, kvImageARGB8888, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
        return nil
    }
    return infoYpCbCrToARGB
}()

/**
 Convert a YpCbCr format pixel buffer into ARGB data.
 - parameter pixelBuffer: Typically captured from the device video camera.
 - parameter argbBuffer: Buffer for ARGB data output. The buffer will be
    resized if needed. Reuse the buffer for best performance.
 */
public func convertYpCbCr(pixelBuffer: CVPixelBuffer, intoARGBBuffer argbBuffer: inout vImage_Buffer) -> Bool {
    // Adapted from Apple's sample code at:
    // https://developer.apple.com/documentation/accelerate/vimage/converting_luminance_and_chrominance_planes_to_an_argb_image?language=objc

    guard var conversionInfoYpCbCrToARGB = _conversionInfoYpCbCrToARGB else {
        return false
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }

    guard CVPixelBufferGetPlaneCount(pixelBuffer) == 2 else {
        return false
    }

    let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
    let lumaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let lumaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
    let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    var sourceLumaBuffer = vImage_Buffer(data: lumaBaseAddress, height: vImagePixelCount(lumaHeight), width: vImagePixelCount(lumaWidth), rowBytes: lumaRowBytes)

    let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    let chromaWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
    let chromaHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
    let chromaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
    var sourceChromaBuffer = vImage_Buffer(data: chromaBaseAddress, height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: chromaRowBytes)

    if argbBuffer.data == nil || argbBuffer.width != sourceLumaBuffer.width || argbBuffer.height != sourceLumaBuffer.height || argbBuffer.rowBytes != sourceLumaBuffer.width * 4 {
        guard vImageBuffer_Init(&argbBuffer, sourceLumaBuffer.height, sourceLumaBuffer.width, 32, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return false
        }
    }
    
    guard vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceLumaBuffer, &sourceChromaBuffer, &argbBuffer, &conversionInfoYpCbCrToARGB, nil, 255, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
        return false
    }
    return true
}

/**
 Return the (A, R, G, B) values in range [0-255] for the pixel at a given
 location in the ARGB buffer.
 - seealso: convertYpCbCr(pixelBuffer:intoARGBBuffer:)
 */
public func argbValues(at point: (x: Int, y: Int), in buffer: vImage_Buffer) -> (a: Int, r: Int, g: Int, b: Int) {
    guard point.x < buffer.width && point.y < buffer.height else {
        return (0, 0, 0, 0)
    }

    let index = point.y * buffer.rowBytes + point.x * 4;
    let argb = unsafeBitCast(buffer.data, to: UnsafePointer<UInt8>.self)
    let a = Int(argb[index])
    let r = Int(argb[index + 1])
    let g = Int(argb[index + 2])
    let b = Int(argb[index + 3])
    return (a, r, g, b)
}
