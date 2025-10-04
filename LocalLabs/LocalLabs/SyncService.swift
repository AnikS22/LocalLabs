//
//  SyncService.swift
//  LocalLabs
//
//  Secure peer-to-peer sync using MultipeerConnectivity
//

import Foundation
import MultipeerConnectivity

/// Service for syncing conversations between devices
@MainActor
@Observable
class SyncService: NSObject {
    /// Singleton instance
    static let shared = SyncService()

    // MARK: - Properties

    /// My peer ID
    private var myPeerID: MCPeerID

    /// Session for peer connectivity
    private var session: MCSession?

    /// Advertiser (for being discovered)
    private var advertiser: MCNearbyServiceAdvertiser?

    /// Browser (for discovering others)
    private var browser: MCNearbyServiceBrowser?

    /// Service type (must be < 15 chars, lowercase, no special chars)
    private let serviceType = "locallabs"

    /// Nearby peers discovered
    private(set) var nearbyPeers: [MCPeerID] = []

    /// Connected peers
    private(set) var connectedPeers: [MCPeerID] = []

    /// Connection state
    private(set) var connectionState: SyncState = .idle

    /// Transfer progress
    private(set) var transferProgress: Double = 0.0

    /// Received conversation (after sync)
    var receivedConversation: TransferableConversation?

    /// Callback for received conversation
    var onConversationReceived: ((TransferableConversation) -> Void)?

    // MARK: - Initialization

    private override init() {
        // Create peer ID with device name
        self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - Session Management

    /// Start advertising (allow others to find this device)
    func startAdvertising() {
        stopAll() // Clean up any existing connections

        // Create session with encryption
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required // Force encryption for security
        )
        session?.delegate = self

        // Start advertising
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        connectionState = .advertising
        print("📡 Started advertising as: \(myPeerID.displayName)")
    }

    /// Start browsing (discover nearby devices)
    func startBrowsing() {
        stopAll() // Clean up any existing connections

        // Create session with encryption
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required // Force encryption
        )
        session?.delegate = self

        // Start browsing
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        connectionState = .browsing
        print("🔍 Started browsing for peers")
    }

    /// Invite a peer to connect
    func invitePeer(_ peerID: MCPeerID) {
        guard let browser = browser else { return }

        browser.invitePeer(
            peerID,
            to: session!,
            withContext: nil,
            timeout: 30
        )

        connectionState = .connecting
        print("📤 Invited peer: \(peerID.displayName)")
    }

    /// Stop all activities
    func stopAll() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        advertiser = nil
        browser = nil
        session = nil

        nearbyPeers.removeAll()
        connectedPeers.removeAll()

        connectionState = .idle
        print("🛑 Stopped all sync activities")
    }

    // MARK: - Data Transfer

    /// Send conversation to a peer
    /// - Parameters:
    ///   - conversation: The transferable conversation to send
    ///   - peer: The peer to send to
    func sendConversation(_ conversation: TransferableConversation, to peer: MCPeerID) throws {
        guard let session = session else {
            throw SyncError.noSession
        }

        guard connectedPeers.contains(peer) else {
            throw SyncError.peerNotConnected
        }

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conversation)

        // Send data
        try session.send(data, toPeers: [peer], with: .reliable)

        transferProgress = 1.0
        print("📤 Sent conversation: \(conversation.title) (\(data.count) bytes)")
    }

    // MARK: - Private Helpers

    /// Handle received data
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            // Decode conversation
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let conversation = try decoder.decode(TransferableConversation.self, from: data)

            receivedConversation = conversation
            onConversationReceived?(conversation)

            print("📥 Received conversation: \(conversation.title) (\(data.count) bytes)")
        } catch {
            print("❌ Failed to decode conversation: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate

extension SyncService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.connectionState = .connected
                print("✅ Connected to: \(peerID.displayName)")

            case .connecting:
                self.connectionState = .connecting
                print("🔄 Connecting to: \(peerID.displayName)")

            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                if self.connectedPeers.isEmpty {
                    self.connectionState = .idle
                }
                print("❌ Disconnected from: \(peerID.displayName)")

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.handleReceivedData(data, from: peerID)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Auto-accept invitations (in production, you'd want user confirmation)
            print("📨 Received invitation from: \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            print("❌ Failed to start advertising: \(error.localizedDescription)")
            self.connectionState = .error(error.localizedDescription)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SyncService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if !self.nearbyPeers.contains(peerID) {
                self.nearbyPeers.append(peerID)
                print("🔍 Found peer: \(peerID.displayName)")
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.nearbyPeers.removeAll { $0 == peerID }
            print("👋 Lost peer: \(peerID.displayName)")
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            print("❌ Failed to start browsing: \(error.localizedDescription)")
            self.connectionState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

/// Sync connection state
enum SyncState: Equatable {
    case idle
    case advertising
    case browsing
    case connecting
    case connected
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Idle"
        case .advertising: return "Advertising..."
        case .browsing: return "Browsing..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

/// Sync-related errors
enum SyncError: LocalizedError {
    case noSession
    case peerNotConnected
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No active sync session"
        case .peerNotConnected:
            return "Peer is not connected"
        case .encodingFailed:
            return "Failed to encode conversation"
        case .decodingFailed:
            return "Failed to decode conversation"
        }
    }
}

/// Transferable conversation (Codable for sync)
struct TransferableConversation: Codable {
    let id: UUID
    let title: String
    let modelName: String
    let createdAt: Date
    let messages: [TransferableMessage]

    init(from conversation: Conversation) {
        self.id = conversation.id
        self.title = conversation.title
        self.modelName = conversation.modelName
        self.createdAt = conversation.createdAt
        self.messages = conversation.messages.map { TransferableMessage(from: $0) }
    }
}

/// Transferable message (Codable for sync)
struct TransferableMessage: Codable {
    let id: UUID
    let content: String
    let role: String
    let timestamp: Date

    init(from message: Message) {
        self.id = message.id
        self.content = message.content
        self.role = message.role.rawValue
        self.timestamp = message.timestamp
    }
}
