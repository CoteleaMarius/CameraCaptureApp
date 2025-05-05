import Foundation
import WebRTC
import UIKit

final class WebRTCClient: NSObject, RTCPeerConnectionDelegate {

    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var videoCapturer: RTCCameraVideoCapturer?

    private var localRenderer: RTCVideoRenderer
    private var remoteRenderer: RTCVideoRenderer

    var onLocalSDPReady: ((RTCSessionDescription) -> Void)?
    var onLocalICECandidate: ((RTCIceCandidate) -> Void)?

    init(localRenderer: RTCVideoRenderer, remoteRenderer: RTCVideoRenderer) {
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        self.localRenderer = localRenderer
        self.remoteRenderer = remoteRenderer
        super.init()
        self.setupPeerConnection()
    }

    private func setupPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan

        config.iceServers = [
            RTCIceServer(
                urlStrings: ["stun:stun.l.google.com:19302"]
            ),
            RTCIceServer(
                urlStrings: ["turn:numb.viagenie.ca"],
                username: "webrtc@live.com", // public
                credential: "muazkh"         // public
            )
        ]

            let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)

        let videoSource = factory.videoSource()
        localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")

        if let videoTrack = localVideoTrack {
            let transceiverInit = RTCRtpTransceiverInit()
            transceiverInit.direction = .sendRecv
            peerConnection?.addTransceiver(with: videoTrack, init: transceiverInit)
        }

        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
    }

    func startCaptureLocalVideo() {
        guard let capturer = videoCapturer else { return }
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) else { return }
        guard let format = RTCCameraVideoCapturer.supportedFormats(for: device).first else { return }
        guard let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate else { return }

        capturer.startCapture(with: device, format: format, fps: Int(fps))
    }

    func offer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { sdp, error in
            guard let sdp = sdp else { return }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { _ in })
            self.onLocalSDPReady?(sdp)
            completion(sdp)
        }
    }

    func answer(completion: @escaping (RTCSessionDescription) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { sdp, error in
            guard let sdp = sdp else { return }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { _ in })
            self.onLocalSDPReady?(sdp)
            completion(sdp)
        }
    }

    func setRemoteDescription(_ sdp: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(sdp, completionHandler: { _ in })
    }

    func addRemoteICECandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }

    // MARK: - RTCPeerConnectionDelegate
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DispatchQueue.main.async {
            print("✅ Stream video primit, trackuri: \(stream.videoTracks.count)")
            if let remoteTrack = stream.videoTracks.first {
                remoteTrack.add(self.remoteRenderer)
                print("📺 Remote video track redat")
            }
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🌍 ICE connection state: \(newState.rawValue)")
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.onLocalICECandidate?(candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
