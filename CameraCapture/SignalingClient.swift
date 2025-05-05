import Foundation
import FirebaseDatabase
import WebRTC

extension RTCSdpType {
    var stringValue: String {
        switch self {
        case .offer: return "offer"
        case .answer: return "answer"
        case .prAnswer: return "pranswer"
        case .rollback: return "rollback"
        @unknown default: return "unknown"
        }
    }
}

final class SignalingClient {
    private let dbRef: DatabaseReference

    init() {
        // Folosește explicit URL-ul bazei de date Firebase
        let database = Database.database(url: "https://camerastream2-13c2b-default-rtdb.europe-west1.firebasedatabase.app")
        self.dbRef = database.reference().child("signaling")
    }

    // Trimite un SDP (offer sau answer)
    func send(sdp: RTCSessionDescription, from sender: String) {
        let sdpDict: [String: Any] = [
            "type": sdp.type.stringValue,
            "sdp": sdp.sdp
        ]
        dbRef.child(sender).child("sdp").setValue(sdpDict)
    }

    // Trimite un ICE Candidate
    func send(candidate: RTCIceCandidate, from sender: String) {
        let candidateDict: [String: Any] = [
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? "",
            "candidate": candidate.sdp
        ]
        dbRef.child(sender).child("candidates").childByAutoId().setValue(candidateDict)
    }

    // Primește SDP (offer/answer) de la alt utilizator
    func observeSDP(for user: String, onReceive: @escaping (RTCSessionDescription) -> Void) {
        dbRef.child(user).child("sdp").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any],
                  let sdpString = value["sdp"] as? String,
                  let typeString = value["type"] as? String else { return }

            let type: RTCSdpType
            switch typeString.lowercased() {
            case "offer": type = .offer
            case "answer": type = .answer
            case "pranswer": type = .prAnswer
            default: return
            }

            let desc = RTCSessionDescription(type: type, sdp: sdpString)
            onReceive(desc)
        })
    }

    // Primește ICE Candidate de la alt utilizator
    func observeCandidates(for user: String, onReceive: @escaping (RTCIceCandidate) -> Void) {
        dbRef.child(user).child("candidates").observe(.childAdded, with: { snapshot in
            guard let value = snapshot.value as? [String: Any],
                  let sdp = value["candidate"] as? String,
                  let sdpMLineIndex = value["sdpMLineIndex"] as? Int32,
                  let sdpMid = value["sdpMid"] as? String else { return }

            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            onReceive(candidate)
        })
    }
}
