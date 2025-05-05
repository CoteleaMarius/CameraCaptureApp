import UIKit
import WebRTC

class ViewController: UIViewController {

    private var webRTCClient: WebRTCClient!
    private var signalingClient: SignalingClient!

    private var localID: String = ""
    private var remoteID: String = ""

    private var remoteView: RTCMTLVideoView!
    private var localView: RTCMTLVideoView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Afișează UI de alegere
        showRoleSelectionUI()
    }

    private func showRoleSelectionUI() {
        let callerButton = UIButton(type: .system)
        callerButton.setTitle("Start as Caller", for: .normal)
        callerButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        callerButton.addTarget(self, action: #selector(startAsCaller), for: .touchUpInside)
        callerButton.frame = CGRect(x: 50, y: 200, width: view.bounds.width - 100, height: 60)
        callerButton.backgroundColor = .systemGreen
        callerButton.setTitleColor(.white, for: .normal)
        callerButton.layer.cornerRadius = 10
        view.addSubview(callerButton)

        let calleeButton = UIButton(type: .system)
        calleeButton.setTitle("Start as Callee", for: .normal)
        calleeButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        calleeButton.addTarget(self, action: #selector(startAsCallee), for: .touchUpInside)
        calleeButton.frame = CGRect(x: 50, y: 300, width: view.bounds.width - 100, height: 60)
        calleeButton.backgroundColor = .systemBlue
        calleeButton.setTitleColor(.white, for: .normal)
        calleeButton.layer.cornerRadius = 10
        view.addSubview(calleeButton)
    }

    @objc private func startAsCaller() {
        localID = "caller"
        remoteID = "callee"
        startCall()
    }

    @objc private func startAsCallee() {
        localID = "callee"
        remoteID = "caller"
        startCall()
    }

    private func startCall() {
        view.subviews.forEach { $0.removeFromSuperview() } // curăță UI

        // Inițializează view-urile video
        remoteView = RTCMTLVideoView(frame: view.bounds)
        remoteView.videoContentMode = .scaleAspectFill
        remoteView.backgroundColor = .black
        view.addSubview(remoteView)

        localView = RTCMTLVideoView(frame: CGRect(x: 20, y: 40, width: 120, height: 160))
        localView.videoContentMode = .scaleAspectFill
        localView.backgroundColor = .darkGray
        view.addSubview(localView)
        view.bringSubviewToFront(localView)

        // Inițializează WebRTC și Firebase Signaling
        webRTCClient = WebRTCClient(localRenderer: localView, remoteRenderer: remoteView)
        signalingClient = SignalingClient()

        webRTCClient.startCaptureLocalVideo()

        // Trimite SDP când e pregătit
        webRTCClient.onLocalSDPReady = { [weak self] sdp in
            self?.signalingClient.send(sdp: sdp, from: self?.localID ?? "")
        }

        // Trimite ICE local
        webRTCClient.onLocalICECandidate = { [weak self] candidate in
            self?.signalingClient.send(candidate: candidate, from: self?.localID ?? "")
        }

        // Ascultă SDP de la peer
        signalingClient.observeSDP(for: remoteID) { [weak self] remoteSDP in
            self?.webRTCClient.setRemoteDescription(remoteSDP)

            if remoteSDP.type == .offer {
                self?.webRTCClient.answer { answer in
                    self?.signalingClient.send(sdp: answer, from: self?.localID ?? "")
                }
            }
        }

        // Ascultă ICE Candidates de la peer
        signalingClient.observeCandidates(for: remoteID) { [weak self] candidate in
            self?.webRTCClient.addRemoteICECandidate(candidate)
        }

        // Dacă suntem initiator, trimitem oferta
        if localID == "caller" {
            webRTCClient.offer { offer in
                self.signalingClient.send(sdp: offer, from: self.localID)
            }
        }
    }
}
