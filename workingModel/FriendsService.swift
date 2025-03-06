import FirebaseFirestore
import FirebaseAuth

class FriendsService {
    static let shared = FriendsService()
    
    private let db = Firestore.firestore()
    
    // Fetch User Details using uid
    func fetchUserDetails(uid: String, completion: @escaping (User?, Error?) -> Void) {
        db.collection("users").whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
            } else if let snapshot = snapshot, !snapshot.isEmpty {
                let userDocument = snapshot.documents.first
                if let user = try? userDocument?.data(as: User.self) {
                    completion(user, nil)
                } else {
                    completion(nil, nil)
                }
            } else {
                completion(nil, nil)
            }
        }
    }

    // Send Friend Request
    func sendFriendRequest(fromUserID: String, toUserID: String, completion: @escaping (Bool, Error?) -> Void) {
        let request = FriendRequest(id: UUID().uuidString, fromUserID: fromUserID, toUserID: toUserID)
        db.collection("friend_requests").document(request.id).setData([
            "id": request.id,
            "fromUserID": request.fromUserID,
            "toUserID": request.toUserID
        ]) { error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }

    // Accept Friend Request
    func acceptFriendRequest(requestID: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("friend_requests").document(requestID).getDocument { [weak self] document, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let data = document?.data(),
                  let fromUserID = data["fromUserID"] as? String,
                  let toUserID = data["toUserID"] as? String else {
                completion(false, nil)
                return
            }
            
            let friend1 = Friend(id: UUID().uuidString, userID: fromUserID, friendID: toUserID)
            let friend2 = Friend(id: UUID().uuidString, userID: toUserID, friendID: fromUserID)
            
            let batch = self?.db.batch()
            
            let friend1Ref = self?.db.collection("friends").document(friend1.id)
            batch?.setData([
                "id": friend1.id,
                "userID": friend1.userID,
                "friendID": friend1.friendID
            ], forDocument: friend1Ref!)
            
            let friend2Ref = self?.db.collection("friends").document(friend2.id)
            batch?.setData([
                "id": friend2.id,
                "userID": friend2.userID,
                "friendID": friend2.friendID
            ], forDocument: friend2Ref!)
            
            let requestRef = self?.db.collection("friend_requests").document(requestID)
            batch?.deleteDocument(requestRef!)
            
            batch?.commit { error in
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // Remove Friend
    func removeFriend(userID: String, friendID: String, completion: @escaping (Bool, Error?) -> Void) {
        let userFriendRef = db.collection("friends").whereField("userID", isEqualTo: userID).whereField("friendID", isEqualTo: friendID)
        let friendUserRef = db.collection("friends").whereField("userID", isEqualTo: friendID).whereField("friendID", isEqualTo: userID)
        
        let batch = db.batch()
        
        userFriendRef.getDocuments { snapshot, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            snapshot?.documents.forEach { document in
                batch.deleteDocument(document.reference)
            }
            
            friendUserRef.getDocuments { snapshot, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // Remove Friend Request
    func removeFriendRequest(requestID: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("friend_requests").document(requestID).delete { error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
    
    // Unsend Friend Request
    func unsendFriendRequest(fromUserID: String, toUserID: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("friend_requests").whereField("fromUserID", isEqualTo: fromUserID).whereField("toUserID", isEqualTo: toUserID).getDocuments { snapshot, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let document = snapshot?.documents.first else {
                completion(false, nil)
                return
            }
            
            document.reference.delete { error in
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }

    // Fetch Friends
    func fetchFriends(forUserID userID: String, completion: @escaping ([Friend]?, Error?) -> Void) {
        db.collection("friends").whereField("userID", isEqualTo: userID).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let friends = snapshot?.documents.compactMap { document -> Friend? in
                try? document.data(as: Friend.self)
            }
            completion(friends, nil)
        }
    }

    // Fetch Friend Requests
    func fetchFriendRequests(forUserID userID: String, completion: @escaping ([FriendRequest]?, Error?) -> Void) {
        db.collection("friend_requests").whereField("toUserID", isEqualTo: userID).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let requests = snapshot?.documents.compactMap { document -> FriendRequest? in
                try? document.data(as: FriendRequest.self)
            }
            completion(requests, nil)
        }
    }

    // Fetch All Users
    func fetchAllUsers(completion: @escaping ([User]?, Error?) -> Void) {
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let users = snapshot?.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }
            completion(users, nil)
        }
    }

    // Fetch Users Excluding Friends and Pending Requests
    func fetchUsersExcludingFriendsAndRequests(currentUserID: String, completion: @escaping ([User]?, Error?) -> Void) {
        fetchFriends(forUserID: currentUserID) { [weak self] friends, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let friendIDs = friends?.map { $0.friendID } ?? []
            
            self?.fetchFriendRequests(forUserID: currentUserID) { requests, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let pendingRequestIDs = requests?.map { $0.fromUserID } ?? []
                
                self?.fetchAllUsers { users, error in
                    if let error = error {
                        completion(nil, error)
                        return
                    }
                    
                    let filteredUsers = users?.filter { user in
                        !friendIDs.contains(user.id) && !pendingRequestIDs.contains(user.id) && user.id != currentUserID
                    }
                    completion(filteredUsers, nil)
                }
            }
        }
    }
}
