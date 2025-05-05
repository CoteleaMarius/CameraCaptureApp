import UIKit
import WebRTC

class ViewController: UIViewController {

    private var webRTCClient: WebRTCClient!
    private var signalingClient: SignalingClient!

    private let localID = "callee"      // sau "callee"
    private let remoteID = "caller"     // sau "caller"

    private var remoteView: RTCMTLVideoView!
    private var localView: RTCMTLVideoView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 1. Inițializează view-urile video
        remoteView = RTCMTLVideoView(frame: view.bounds)
        remoteView.videoContentMode = .scaleAspectFill
        remoteView.backgroundColor = .black
        view.addSubview(remoteView)

        localView = RTCMTLVideoView(frame: CGRect(x: 20, y: 40, width: 120, height: 160))
        localView.videoContentMode = .scaleAspectFill
        localView.backgroundColor = .darkGray
        view.addSubview(localView)
        view.bringSubviewToFront(localView)

        // 2. Inițializează WebRTC și Firebase Signaling
        webRTCClient = WebRTCClient(localRenderer: localView, remoteRenderer: remoteView)
        signalingClient = SignalingClient()

        // 3. Pornește capturarea camerei locale
        webRTCClient.startCaptureLocalVideo()

        // 4. Trimite SDP local
        webRTCClient.onLocalSDPReady = { [weak self] sdp in
            self?.signalingClient.send(sdp: sdp, from: self?.localID ?? "")
        }

        // 5. Trimite ICE local
        webRTCClient.onLocalICECandidate = { [weak self] candidate in
            self?.signalingClient.send(candidate: candidate, from: self?.localID ?? "")
        }

        // 6. Ascultă SDP de la peer
        signalingClient.observeSDP(for: remoteID) { [weak self] remoteSDP in
            self?.webRTCClient.setRemoteDescription(remoteSDP)

            if remoteSDP.type == .offer {
                self?.webRTCClient.answer { answer in
                    self?.signalingClient.send(sdp: answer, from: self?.localID ?? "")
                }
            }
        }

        // 7. Ascultă ICE Candidates de la peer
        signalingClient.observeCandidates(for: remoteID) { [weak self] candidate in
            self?.webRTCClient.addRemoteICECandidate(candidate)
        }

        // 8. Dacă suntem initiator, facem oferta
        if localID == "caller" {
            webRTCClient.offer { offer in
                self.signalingClient.send(sdp: offer, from: self.localID)
            }
        }
    }
}
