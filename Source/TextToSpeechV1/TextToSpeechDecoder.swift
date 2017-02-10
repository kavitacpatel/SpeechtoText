/**
 * Copyright IBM Corporation 2016-2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import AudioToolbox

internal class TextToSpeechDecoder {
    
    private typealias opus_decoder = OpaquePointer
    
    //    private var buffer: oggpack_buffer
    private var decoder: opus_decoder   // decoder to convert opus to pcm
    private var header: OpusHeader = OpusHeader.init()
    private var page: ogg_page
    private var streamState: ogg_stream_state    // state of ogg stream?
    private var packet: ogg_packet          // packet within a stream passing information
    private var packetCount: Int64 = 0
    private var syncState: ogg_sync_state        // state of ogg sync
    private var beginStream = true
    private var pageGranulePosition: Int64 = 0     // Position of the packet data at page
    private var hasOpusStream = false
    private var hasTagsPacket = false
    private var opusSerialNumber: Int = 0
    private var linkOut: Int32 = 0
    private var totalLinks: Int = 0
    private var numChannels: Int32 = 1
    var pcmDataBuffer = UnsafeMutablePointer<Float>.allocate(capacity: 0)
    var pcmData = Data()
    
    private var sampleRate = Int32(48000)
    private var preSkip = Int32(0)
    
    private var granOffset: Int32 = 0
    private var frameSize: Int32 = 0
    
    private let MAX_FRAME_SIZE = Int32(960 * 6)
    
    convenience init(data: Data) throws {
        
        try self.init(
            audioData: data
        )
        
    }
    
    init(audioData: Data) throws {
        // set properties
        streamState = ogg_stream_state()
        syncState = ogg_sync_state()
        page = ogg_page()
        packet = ogg_packet()
        
        // Status to catch errors
        var status = Int32(0)
        
        decoder = opus_decoder_create(sampleRate, numChannels, &status)
        
        // initialize ogg sync state
        ogg_sync_init(&syncState)
        var processedByteCount = 0 // guarantee data is pulled from stream.
        
        while processedByteCount < audioData.count {
            
            // write into buffer of size __
            var bufferSize: Int
            
            if audioData.count - processedByteCount > 200 {
                bufferSize = 200
            } else {
                bufferSize = audioData.count - processedByteCount
            }
            //        var bufferData = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
            var bufferData: UnsafeMutablePointer<Int8>
            
            //        let range = Range(uncheckedBounds: (lower: processedByteCount, upper: bufferSize))
            bufferData = ogg_sync_buffer(&syncState, bufferSize)
            
            bufferData.withMemoryRebound(to: UInt8.self, capacity: bufferSize) {
                bufferDataUInt8 in
                
//                audioData.copyBytes(to: bufferDataUInt8, count: bufferSize)
                audioData.copyBytes(to: bufferDataUInt8, from: processedByteCount..<processedByteCount + bufferSize)
            }
            //
            //
            //        for index in processedByteCount..<bufferSize+processedByteCount {
            //            print (bufferData[index])
            //            bufferData[index] = Int8(audioData[index])
            //        }
            
            processedByteCount += bufferSize
            /// Advance pointer to end of processed data
            ogg_sync_wrote(&syncState, bufferSize)
            
//            let receivedData =
            while (ogg_sync_pageout(&syncState, &page) == 1) {
                if beginStream {
                    /// Assign stream's number with the page.
                    ogg_stream_init(&streamState, ogg_page_serialno(&page))
                    beginStream = false
                }
                /// If ogg page's serial number does not match stream's serial number
                /// reset stream's serial number because.... ___
                if (ogg_page_serialno(&page) != Int32(streamState.serialno)) {
                    ogg_stream_reset_serialno(&streamState, ogg_page_serialno(&page))
                }
                
                /// Add page to the stream.
                ogg_stream_pagein(&streamState, &page)
                
                /// Check granularity position?
                pageGranulePosition = ogg_page_granulepos(&page)
                
                /// While there's a packet, extract.
                try extractPacket(&streamState, &packet)
                
                //            while (ogg_stream_packetout(&streamState, &packet) == 1) {
                //                /// Check for initial stream header
                //                if (packet.bytes >= 8 && packet.b_o_s == 1) {
                //
                //                }
                //            }
                
                // initialize ogg stream state to allocate memory to decode. Returns 0 if successful.
                //        let status = ogg_stream_init(&streamState, serial)
                //        guard status == 0 else {
                //            throw OpusError.internalError
                //        }
                // build buffer.
                
            }
        }
        if totalLinks == 0 {
            NSLog("Does not look like an opus file.")
            
            throw OpusError.invalidState
        }
        opus_multistream_decoder_destroy(decoder)
        if (!beginStream) {
            ogg_stream_clear(&streamState)
        }
        ogg_sync_clear(&syncState)
        
        //TODO: - check this is the right place to deallocate pcmDataBuffer
        pcmDataBuffer.deallocate(capacity: MemoryLayout<Float>.stride * Int(MAX_FRAME_SIZE) * Int(numChannels))
        
    }
    

    private func extractPacket(_ streamState: inout ogg_stream_state, _ packet: inout ogg_packet) throws {
        
        while (ogg_stream_packetout(&streamState, &packet) == 1) {
            /// Execute if initial stream header.
            if (packet.bytes >= 8 && packet.b_o_s == 256 && (memcmp(packet.packet, "OpusHead", 8) == 0)) {
                /// Check if there's another opus head to see if stream is chained without EOS.
                if (hasOpusStream && hasTagsPacket) {
                    hasOpusStream = false
                    // TODO - how to check if decoder exists.  Should we use opus_decoder_destroy instead?
                    opus_multistream_decoder_destroy(decoder)
                    NSLog("decoder destroyed. kaboom.")
                }
                
                /// Reset packet flags if not in opus streams.
                if (!hasOpusStream) {
                    if (packetCount > 0 && opusSerialNumber == streamState.serialno) {
                        NSLog("Apparent chaining without changing serial number. Something bad happened.")
                        throw OpusError.internalError
                    }
                    opusSerialNumber = streamState.serialno
                    hasOpusStream = true
                    hasTagsPacket = false
                    linkOut = 0
                    packetCount = 0
                    totalLinks += 1
                } else {
                    NSLog("Warning: ignoring opus stream.")
                }
            }
            
            if (!hasOpusStream || streamState.serialno != opusSerialNumber) {
                break
            }
            
            // If first packet is in logical stream, process header
            if packetCount == 0 {
                // set decoder to identified header
                guard let decoder = try? processHeader(&packet, &numChannels, &preSkip) else {
                    throw OpusError.invalidPacket
                }
                /// Check that there are no more packets in the page.
                if (ogg_stream_packetout(&streamState, &packet) != 0 || page.header[page.header_len - 1] == 255) {
                    throw OpusError.invalidPacket
                }
                
                granOffset = preSkip
                
                pcmDataBuffer = UnsafeMutablePointer<Float>.allocate(capacity: MemoryLayout<Float>.stride * Int(MAX_FRAME_SIZE) * Int(numChannels))
                
            } else if (packetCount == 1) {
                hasTagsPacket = true
                if (ogg_stream_packetout(&streamState, &packet) != 0 || page.header[page.header_len-1] == 255) {
                    NSLog("Extra packets on initial tags page. Invalid stream.")
                    
                    throw OpusError.invalidPacket
                }
            } else {
                var numberOfSamplesDecoded: Int32
                var maxOut: Int64
                var outSample: Int64
                
                /// Decode opus packet.
                numberOfSamplesDecoded = opus_multistream_decode_float(decoder, packet.packet, Int32(packet.bytes), pcmDataBuffer, MAX_FRAME_SIZE, 0)
                
                if numberOfSamplesDecoded < 0 {
                    NSLog("Decoding error: \(opus_strerror(numberOfSamplesDecoded))")
                    throw OpusError.internalError
                }
                
                frameSize = numberOfSamplesDecoded
                
                /// Make sure the output duration follows the final end-trim
                /// Output sample count should not be ahead of granpos value.
                maxOut = ((pageGranulePosition - Int64(granOffset)) * Int64(sampleRate) / 48000) - Int64(linkOut)
                outSample = try audioWrite(&pcmDataBuffer, numChannels, frameSize, &preSkip, &maxOut)
                
                linkOut = Int32(outSample) + linkOut
                
            }
            packetCount += 1
//            print (packet.e_o_s)
        }
        
    }
    
    /// channels - used to __
    private func processHeader(_ packet: inout ogg_packet, _ channels: inout Int32, _ preskip: inout Int32) throws -> opus_decoder {
        
        // create status to capture errors
        var error = Int32(0)
        
        // TODO - figure out where opus header header files should live.
        if (opus_header_parse(packet.packet, Int32(packet.bytes), &header) == 0) {
            throw OpusError.invalidPacket
        }
        channels = header.channels
        preskip = header.preskip
        
        /// TODO - check weird stream_map.0
        decoder = opus_multistream_decoder_create(sampleRate, channels, header.nb_streams, header.nb_coupled, &header.stream_map.0, &error)
        if error != OpusError.ok.rawValue {
            throw OpusError.badArgument
        }
        return decoder
    }
    
    /// Returns number of bytes written (?)
    // put pcm uffer into pcm data
    private func audioWrite(_ pcmDataBuffer: inout UnsafeMutablePointer<Float>,
                            _ channels: Int32,
                            _ frameSize: Int32,
                            _ skip: inout Int32,
                            _ maxOut: inout Int64) throws -> Int64 {
        /// Save pointer(?)
//        var pcmDataBuffer = pcmDataBuffer
        var sampOut: Int64 = 0
        var tmpSkip: Int32
        var outLength: UInt
//        var out: UnsafeMutablePointer<CShort>
        var output: UnsafeMutablePointer<Float>
//        out = UnsafeMutablePointer<CShort>.allocate(capacity: MemoryLayout<CShort>.stride * Int(MAX_FRAME_SIZE) * Int(channels))
        if maxOut < 0 {
            maxOut = 0
        }
        
        if skip != 0 {
            if skip > frameSize {
                tmpSkip = frameSize
            } else {
                tmpSkip = skip
            }
            skip -= tmpSkip
        } else {
            tmpSkip = 0
        }
        output = pcmDataBuffer.advanced(by: Int(channels) * Int(tmpSkip))
        
        outLength = UInt(frameSize) - UInt(tmpSkip)
        
        // TODO - convert possibly short to float.
//        let maxLoop = Int(outLength) * Int(channels)
//        for (i in 0..< maxLoop) {
//            out[i] = max(-32768, min(&output[i]*Float(32768), 32767))
//        }

        // TODO - convert output (float) to UnsafePointer<Int8>
        
        // TODO: check capacity in the unsafemutableRawPointer func

        
        let u8UnsafeMutableRawPointer = UnsafeMutableRawPointer(output).bindMemory(to: UInt8.self, capacity: Int(outLength) * Int(channels))
        let u8UnsafePointer = UnsafePointer(u8UnsafeMutableRawPointer)
        
        if maxOut > 0 {
            pcmData.append(u8UnsafePointer, count: Int(outLength))
            sampOut = sampOut + Int64(outLength)
        }
        
        return sampOut

    }
}

internal enum OpusError: Error {
    case ok
    case badArgument
    case bufferTooSmall
    case internalError
    case invalidPacket
    case unimplemented
    case invalidState
    case allocationFailure
    
    var rawValue: Int32 {
        switch self {
        case .ok: return OPUS_OK
        case .badArgument: return OPUS_BAD_ARG
        case .bufferTooSmall: return OPUS_BUFFER_TOO_SMALL
        case .internalError: return OPUS_INTERNAL_ERROR
        case .invalidPacket: return OPUS_INVALID_PACKET
        case .unimplemented: return OPUS_UNIMPLEMENTED
        case .invalidState: return OPUS_INVALID_STATE
        case .allocationFailure: return OPUS_ALLOC_FAIL
        }
    }
    
    init?(rawValue: Int32) {
        switch rawValue {
        case OPUS_OK: self = .ok
        case OPUS_BAD_ARG: self = .badArgument
        case OPUS_BUFFER_TOO_SMALL: self = .bufferTooSmall
        case OPUS_INTERNAL_ERROR: self = .internalError
        case OPUS_INVALID_PACKET: self = .invalidPacket
        case OPUS_UNIMPLEMENTED: self = .unimplemented
        case OPUS_INVALID_STATE: self = .invalidState
        case OPUS_ALLOC_FAIL: self = .allocationFailure
        default: return nil
        }
    }
}

// MARK: - OggError
internal enum OggError: Error {
    case outOfSync
    case internalError
}
