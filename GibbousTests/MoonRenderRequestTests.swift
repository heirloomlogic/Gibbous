//
//  MoonRenderRequestTests.swift
//  GibbousTests
//
//  The pure pieces of the render pipeline that need no Metal device: the
//  readout→request mapping the views build, and the phase-angle→sun-direction
//  math the shader is fed.
//

import Foundation
import Testing
import simd

@testable import Gibbous

struct MoonRenderRequestTests {
    // MARK: readout → request

    @Test func modernRequestMapsReadoutFieldsAndUsesTheModernLook() {
        let r = SampleReadout.make()
        let request = MoonRenderRequest(readout: r, style: .modern)
        #expect(request.look == .modern)
        #expect(request.phaseAngleDegrees == r.phaseAngleDegrees)
        #expect(request.subEarthLatitudeDegrees == r.subEarthLatitude)
        #expect(request.subEarthLongitudeDegrees == r.subEarthLongitude)
        #expect(request.rollDegrees == r.axisPositionAngleDegrees)
        #expect(request.transparentOutside)
        #expect(request.ditherCell == 1)
        #expect(request.ambient == 0.015)  // default
    }

    @Test func retroStyleSelectsTheRetroLook() {
        let request = MoonRenderRequest(readout: SampleReadout.make(), style: .retro)
        #expect(request.look == .retro)
    }

    @Test func glyphOverridesAmbientAndDitherWithoutMutatingAfterInit() {
        let request = MoonRenderRequest(readout: SampleReadout.make(), style: .retro, ditherCell: 3, ambient: 0.05)
        #expect(request.ambient == 0.05)
        #expect(request.ditherCell == 3)
    }

    // MARK: phase angle → sun direction

    @Test func sunDirectionTracksThePhaseAngle() {
        let tol: Float = 1e-6
        // 0° new: sun behind the disc (−z).
        #expect(simd_distance(MoonRenderer.sunDirection(phaseAngleDegrees: 0), SIMD3(0, 0, -1)) < tol)
        // 90° first quarter: lit from the right (+x).
        #expect(simd_distance(MoonRenderer.sunDirection(phaseAngleDegrees: 90), SIMD3(1, 0, 0)) < tol)
        // 180° full: sun toward the viewer (+z).
        #expect(simd_distance(MoonRenderer.sunDirection(phaseAngleDegrees: 180), SIMD3(0, 0, 1)) < tol)
        // 270° third quarter: lit from the left (−x).
        #expect(simd_distance(MoonRenderer.sunDirection(phaseAngleDegrees: 270), SIMD3(-1, 0, 0)) < tol)
    }

    @Test func sunDirectionIsAlwaysAUnitVectorInThePlane() {
        for angle in stride(from: 0.0, through: 360.0, by: 30.0) {
            let s = MoonRenderer.sunDirection(phaseAngleDegrees: angle)
            #expect(abs(simd_length(s) - 1) < 1e-6)
            #expect(abs(s.y) < 1e-6)  // the sun stays in the x–z plane
        }
    }

    @Test func moonLookRawValuesMatchTheShaderContract() {
        #expect(MoonLook.modern.rawValue == 0)
        #expect(MoonLook.blackAndWhite.rawValue == 1)
        #expect(MoonLook.retro.rawValue == 2)
    }
}
