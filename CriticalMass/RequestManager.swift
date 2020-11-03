//
//  RequestManager.swift
//  CriticalMaps
//
//  Created by Leonard Thomas on 12/17/18.
//

import Foundation
import os.log
import UIKit

@available(macOS 10.12, *)
public class RequestManager {
    public enum Constants {
        static let foregroundRefreshInterval: TimeInterval = 6
        static let receivedFailureRefreshInterval: TimeInterval = 4
    }

    private var dataStore: DataStore
    private var locationProvider: LocationProvider
    private var networkLayer: NetworkLayer
    private var idProvider: IDProvider
    private var networkObserver: NetworkObserver?
    private var errorHandler: ErrorHandler

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var refreshInterval: TimeInterval = Constants.foregroundRefreshInterval

    private var log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "", category: "RequestManager")

    public init(
        dataStore: DataStore,
        locationProvider: LocationProvider,
        networkLayer: NetworkLayer,
        interval: TimeInterval,
        idProvider: IDProvider,
        errorHandler: ErrorHandler = PrintErrorHandler(),
        networkObserver: NetworkObserver?
    ) {
        self.idProvider = idProvider
        self.dataStore = dataStore
        self.locationProvider = locationProvider
        self.networkLayer = networkLayer
        self.networkObserver = networkObserver
        self.errorHandler = errorHandler
        refreshInterval = interval

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(didReceiveLocationsUpdate),
            name: .locationAndMessagesReceived,
            object: nil
        )



        setupNetworkObserver()
        addUpdateOperation()
    }

    private func addUpdateOperation() {
        let updateDataOperation = UpdateDataOperation(
            locationProvider: locationProvider,
            idProvider: idProvider,
            networkLayer: networkLayer
        )
        updateDataOperation.completionBlock = { [weak self] in
            guard let self = self else { return }

            if let result = updateDataOperation.result {
                self.defaultCompletion(for: result)
            }

            self.addUpdateOperation()
        }

        let waitOperation = WaitOperation(with: refreshInterval)
        operationQueue.addOperation(waitOperation)

        let updateLocationOperation = UpdateLocationOperation(locationProvider: locationProvider)
        operationQueue.addOperation(updateLocationOperation)

        operationQueue.addOperation(updateDataOperation)
    }

    private func defaultCompletion(for result: ApiResponseResult) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.dataStore.update(with: result)
            switch result {
            case .success:
                Logger.log(.info, log: self.log, "Successfully finished API update")
            case let .failure(error):
                self.errorHandler.handleError(error)
                Logger.log(.error, log: self.log, "API update failed")
            }
        }
    }

    public func getData() {
        UpdateDataOperation(locationProvider: nil, idProvider: idProvider, networkLayer: networkLayer)
            .performWithoutQueue { [weak self] result in
                self?.defaultCompletion(for: result)
            }
    }

    func send(messages: [SendChatMessage], completion: @escaping ResultCallback<[String: ChatMessage]>) {
        UpdateDataOperation(locationProvider: nil, idProvider: idProvider, networkLayer: networkLayer, messages: messages)
            .performWithoutQueue { [weak self] result in
                self?.defaultCompletion(for: result)
                onMain {
                    switch result {
                    case let .success(messages):
                        completion(.success(messages.chatMessages))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
    }

    @objc private func didReceiveLocationsUpdate(notification: Notification) {
        guard let result = notification.object as? ApiResponseResult else {
            return
        }
        if result.failed {
            refreshInterval = Constants.receivedFailureRefreshInterval
        } else {
            refreshInterval = Constants.foregroundRefreshInterval
        }
    }
}

@available(macOS 10.12, *)
private extension RequestManager {
    func setupNetworkObserver() {
        networkObserver?.statusUpdateHandler = { [weak self] status in
            guard let self = self, status == .satisfied else {
                return
            }

            let operation = self.operationQueue.operations.first
            if operation is WaitOperation {
                operation?.cancel()
            }
        }
    }
}
