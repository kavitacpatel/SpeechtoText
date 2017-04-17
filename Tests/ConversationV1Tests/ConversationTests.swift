/**
 * Copyright IBM Corporation 2016
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

import XCTest
import Foundation
import ConversationV1

class ConversationTests: XCTestCase {
    
    private var conversation: Conversation!
    private let workspaceID = "8d869397-411b-4f0a-864d-a2ba419bb249"
    private let timeout: TimeInterval = 5.0

    // MARK: - Test Configuration

    /** Set up for each test by instantiating the service. */
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        instantiateConversation()
    }
    
    static var allTests : [(String, (ConversationTests) -> () throws -> Void)] {
        return [
            ("instantiateConversation", instantiateConversation),
            ("testMessage", testMessage),
            ("testMessageAllFields1", testMessageAllFields1),
            ("testMessageAllFields2", testMessageAllFields2),
            ("testMessageInvalidWorkspace", testMessageInvalidWorkspace)
        ]
    }

    /** Instantiate Conversation. */
    func instantiateConversation() {
        let username = Credentials.ConversationUsername
        let password = Credentials.ConversationPassword
        let version = "2017-04-21"
        conversation = Conversation(username: username, password: password, version: version)
    }

    /** Fail false negatives. */
    func failWithError(error: Error) {
        XCTFail("Positive test failed with error: \(error)")
    }

    /** Fail false positives. */
    func failWithResult<T>(result: T) {
        XCTFail("Negative test returned a result.")
    }

    /** Wait for expectations. */
    func waitForExpectations() {
        waitForExpectations(timeout: timeout) { error in
            XCTAssertNil(error, "Timeout")
        }
    }

    // MARK: - Positive Tests
    
    func testMessage() {
        let description1 = "Start a conversation."
        let expectation1 = self.expectation(description: description1)
        
        let response1 = ["Hi. It looks like a nice drive today. What would you like me to do?"]
        let nodes1 = ["node_1_1467221909631"]
        
        var context: Context?
        conversation.message(withWorkspace: workspaceID, failure: failWithError) {
            response in
            
            // verify input
            XCTAssertNil(response.input)
            
            // verify context
            XCTAssertNotNil(response.context.conversationID)
            XCTAssertNotEqual(response.context.conversationID, "")
            XCTAssertNotNil(response.context.system)
            XCTAssertEqual(response.context.system.dialogStack, ["root"])
            XCTAssertEqual(response.context.system.dialogTurnCounter, 1)
            XCTAssertEqual(response.context.system.dialogRequestCounter, 1)
            
            // verify entities
            XCTAssertTrue(response.entities.isEmpty)
            
            // verify intents
            XCTAssertTrue(response.intents.isEmpty)
            
            // verify output
            XCTAssertTrue(response.output.logMessages.isEmpty)
            XCTAssertEqual(response.output.text, response1)
            XCTAssertEqual(response.output.nodesVisited, nodes1)
            
            context = response.context
            expectation1.fulfill()
        }
        waitForExpectations()
        
        let description2 = "Continue a conversation."
        let expectation2 = self.expectation(description: description2)
        
        let text = "Turn on the radio."
        let request = MessageRequest(text: text, context: context!)
        let response2 = ["", "Sure thing! Which genre would you prefer? Jazz is my personal favorite.."]
        let nodes2 = ["node_1_1467232431348", "node_2_1467232480480", "node_1_1467994455318"]
        
        conversation.message(withWorkspace: workspaceID, request: request, failure: failWithError) {
            response in
            
            // verify input
            XCTAssertEqual(response.input!.text, text)
            
            // verify context
            XCTAssertEqual(response.context.conversationID, context!.conversationID)
            XCTAssertNotNil(response.context.system)
            XCTAssertEqual(response.context.system.dialogStack, ["node_1_1467994455318"])
            XCTAssertEqual(response.context.system.dialogTurnCounter, 2)
            XCTAssertEqual(response.context.system.dialogRequestCounter, 2)
            
            // verify entities
            XCTAssertEqual(response.entities.count, 1)
            XCTAssertEqual(response.entities[0].entity, "appliance")
            XCTAssertEqual(response.entities[0].startIndex, 12)
            XCTAssertEqual(response.entities[0].endIndex, 17)
            XCTAssertEqual(response.entities[0].value, "music")
            
            // verify intents
            XCTAssertEqual(response.intents.count, 1)
            XCTAssertEqual(response.intents[0].intent, "turn_on")
            XCTAssert(response.intents[0].confidence >= 0.90)
            XCTAssert(response.intents[0].confidence <= 1.00)
            
            // verify output
            XCTAssertTrue(response.output.logMessages.isEmpty)
            XCTAssertEqual(response.output.text, response2)
            XCTAssertEqual(response.output.nodesVisited, nodes2)
            
            expectation2.fulfill()
        }
        waitForExpectations()
    }
    
    func testMessageAllFields1() {
        let description1 = "Start a conversation."
        let expectation1 = expectation(description: description1)
        
        var context: Context?
        var entities: [Entity]?
        var intents: [Intent]?
        var output: Output?
        
        conversation.message(withWorkspace: workspaceID, failure: failWithError) {
            response in
            context = response.context
            entities = response.entities
            intents = response.intents
            output = response.output
            expectation1.fulfill()
        }
        waitForExpectations()
        
        let description2 = "Continue a conversation."
        let expectation2 = expectation(description: description2)
        
        let text2 = "Turn on the radio."
        let request2 = MessageRequest(text: text2, context: context, entities: entities, intents: intents, output: output)
        conversation.message(withWorkspace: workspaceID, request: request2, failure: failWithError) {
            response in
            
            // verify objects are non-nil
            XCTAssertNotNil(entities)
            XCTAssertNotNil(intents)
            XCTAssertNotNil(output)
            
            // verify intents are equal
            for i in 0..<response.intents.count {
                let intent1 = intents![i]
                let intent2 = response.intents[i]
                XCTAssertEqual(intent1.intent, intent2.intent)
                XCTAssertEqualWithAccuracy(intent1.confidence, intent2.confidence, accuracy: 10E-5)
            }
            
            // verify entities are equal
            for i in 0..<response.entities.count {
                let entity1 = entities![i]
                let entity2 = response.entities[i]
                XCTAssertEqual(entity1.entity, entity2.entity)
                XCTAssertEqual(entity1.startIndex, entity2.startIndex)
                XCTAssertEqual(entity1.endIndex, entity2.endIndex)
                XCTAssertEqual(entity1.value, entity2.value)
            }
            
            expectation2.fulfill()
        }
        waitForExpectations()
    }
    
    func testMessageAllFields2() {
        let description1 = "Start a conversation."
        let expectation1 = expectation(description: description1)
        
        var context: Context?
        var entities: [Entity]?
        var intents: [Intent]?
        var output: Output?
        
        conversation.message(withWorkspace: workspaceID, failure: failWithError) {
            response in
            context = response.context
            expectation1.fulfill()
        }
        waitForExpectations()
        
        let description2 = "Continue a conversation."
        let expectation2 = expectation(description: description2)
        
        let text2 = "Turn on the radio."
        let request2 = MessageRequest(text: text2, context: context, entities: entities, intents: intents, output: output)
        conversation.message(withWorkspace: workspaceID, request: request2, failure: failWithError) {
            response in
            context = response.context
            entities = response.entities
            intents = response.intents
            output = response.output
            expectation2.fulfill()
        }
        waitForExpectations()
        
        let description3 = "Continue a conversation with non-empty intents and entities."
        let expectation3 = expectation(description: description3)
        
        let text3 = "Rock music."
        let request3 = MessageRequest(text: text3, context: context, entities: entities, intents: intents, output: output)
        conversation.message(withWorkspace: workspaceID, request: request3, failure: failWithError) {
            response in
            
            // verify objects are non-nil
            XCTAssertNotNil(entities)
            XCTAssertNotNil(intents)
            XCTAssertNotNil(output)
            
            // verify intents are equal
            for i in 0..<response.intents.count {
                let intent1 = intents![i]
                let intent2 = response.intents[i]
                XCTAssertEqual(intent1.intent, intent2.intent)
                XCTAssertEqualWithAccuracy(intent1.confidence, intent2.confidence, accuracy: 10E-5)
            }
            
            // verify entities are equal
            for i in 0..<response.entities.count {
                let entity1 = entities![i]
                let entity2 = response.entities[i]
                XCTAssertEqual(entity1.entity, entity2.entity)
                XCTAssertEqual(entity1.startIndex, entity2.startIndex)
                XCTAssertEqual(entity1.endIndex, entity2.endIndex)
                XCTAssertEqual(entity1.value, entity2.value)
            }
            
            expectation3.fulfill()
        }
        waitForExpectations()
    }
    
    func testMessageGetContextVariable() {
        let description1 = "Start a conversation."
        let expectation1 = expectation(description: description1)
        
        var context: Context?
        conversation.message(withWorkspace: workspaceID, failure: failWithError) {
            response in
            context = response.context
            expectation1.fulfill()
        }
        waitForExpectations()
        
        let description2 = "Continue a conversation."
        let expectation2 = expectation(description: description2)
        
        let text2 = "Turn on the radio."
        let request2 = MessageRequest(text: text2, context: context)
        conversation.message(withWorkspace: workspaceID, request: request2, failure: failWithError) {
            response in
            let reprompt = response.context.json["reprompt"] as? Bool
            XCTAssertNotNil(reprompt)
            XCTAssertTrue(reprompt!)
            expectation2.fulfill()
        }
        waitForExpectations()
    }
    
    func testListAllWorkspaces() {
        let description = "List all workspaces."
        let expectation = self.expectation(description: description)
        
        conversation.listWorkspaces(failure: failWithError) { workspaceResponse in
            XCTAssertGreaterThanOrEqual(workspaceResponse.workspaces.count, 15)
            for workspace in workspaceResponse.workspaces {
                XCTAssertNotNil(workspace.name)
                XCTAssertNotNil(workspace.created)
                XCTAssertNotNil(workspace.updated)
                XCTAssertNotNil(workspace.language)
                XCTAssertNotNil(workspace.metadata)
                XCTAssertNotNil(workspace.workspaceID)
            }
            XCTAssertNotNil(workspaceResponse.pagination.refreshUrl)
            expectation.fulfill()
        }
        waitForExpectations()
    }
    
    func testListAllWorkspacesPageLimit1() {
        let description = "List all workspaces with page limit specified as 1."
        let expectation = self.expectation(description: description)
        
        conversation.listWorkspaces(pageLimit: 1, failure: failWithError) { workspaceResponse in
            XCTAssertEqual(workspaceResponse.workspaces.count, 1)
            for workspace in workspaceResponse.workspaces {
                XCTAssertNotNil(workspace.name)
                XCTAssertNotNil(workspace.created)
                XCTAssertNotNil(workspace.updated)
                XCTAssertNotNil(workspace.language)
                XCTAssertNotNil(workspace.metadata)
                XCTAssertNotNil(workspace.workspaceID)
            }
            XCTAssertNotNil(workspaceResponse.pagination.refreshUrl)
            XCTAssertNotNil(workspaceResponse.pagination.nextUrl)
            expectation.fulfill()
        }
        waitForExpectations()
    }
    
    func testListAllWorkspacesWithCountTrue() {
        let description = "List all workspaces with includeCount as true."
        let expectation = self.expectation(description: description)
        
        conversation.listWorkspaces(includeCount: true, failure: failWithError) { workspaceResponse in
            for workspace in workspaceResponse.workspaces {
                XCTAssertNotNil(workspace.name)
                XCTAssertNotNil(workspace.created)
                XCTAssertNotNil(workspace.updated)
                XCTAssertNotNil(workspace.language)
                XCTAssertNotNil(workspace.metadata)
                XCTAssertNotNil(workspace.workspaceID)
            }
            XCTAssertNotNil(workspaceResponse.pagination.refreshUrl)
            XCTAssertNotNil(workspaceResponse.pagination.total)
            XCTAssertNotNil(workspaceResponse.pagination.matched)
            expectation.fulfill()
        }
        waitForExpectations()
    }
    
    func testCreateAndDeleteWorkspace() {
        var newWorkspace: String?
        
        let description1 = "Create a workspace."
        let expectation1 = expectation(description: description1)

        let workspaceName = "swift-sdk-test-workspace"
        let workspaceDescription = "temporary workspace for the swift sdk unit tests"
        let workspaceLanguage = "en"
        var workspaceMetadata = [String: Any]()
        workspaceMetadata["testKey"] = "testValue"
        let intentExample = CreateExample(text: "This is an example of Intent1")
        let workspaceIntent = CreateIntent(intent: "Intent1", description: "description of Intent1", examples: [intentExample])
        let entityValue = CreateValue(value: "Entity1Value", metadata: workspaceMetadata, synonyms: ["Synonym1", "Synonym2"])
        let workspaceEntity = CreateEntity(entity: "Entity1", description: "description of Entity1", source: "Source of the entity", values: [entityValue])
        let workspaceDialogNode = CreateDialogNode(dialogNode: "DialogNode1", description: "description of DialogNode1")
        let workspaceCounterexample = CreateExample(text: "This is a counterexample")
        
        let createWorkspaceBody = CreateWorkspace(name: workspaceName, description: workspaceDescription, language: workspaceLanguage, metadata: workspaceMetadata, intents: [workspaceIntent], entities: [workspaceEntity], dialogNodes: [workspaceDialogNode], counterexamples: [workspaceCounterexample])
        
        conversation.createWorkspace(body: createWorkspaceBody, failure: failWithError) { workspace in
            XCTAssertEqual(workspace.name, workspaceName)
            XCTAssertEqual(workspace.description, workspaceDescription)
            XCTAssertEqual(workspace.language, workspaceLanguage)
            XCTAssertNotNil(workspace.created)
            XCTAssertNotNil(workspace.updated)
            XCTAssertNotNil(workspace.workspaceID)
            
            newWorkspace = workspace.workspaceID
            expectation1.fulfill()
        }
        waitForExpectations()
        
        guard let newWorkspaceID = newWorkspace else {
            XCTFail("Failed to get the ID of the newly created workspace.")
            return
        }
        
        let description2 = "Get the newly created workspace."
        let expectation2 = expectation(description: description2)
        
        conversation.getWorkspace(workspaceID: newWorkspaceID, export: true, failure: failWithError) { workspace in
            XCTAssertEqual(workspace.name, workspaceName)
            XCTAssertEqual(workspace.description, workspaceDescription)
            XCTAssertEqual(workspace.language, workspaceLanguage)
            XCTAssertNotNil(workspace.metadata)
            XCTAssertNotNil(workspace.created)
            XCTAssertNotNil(workspace.updated)
            XCTAssertEqual(workspace.workspaceID, newWorkspaceID)
            XCTAssertNotNil(workspace.status)
            
            XCTAssertNotNil(workspace.intents)
            for intent in workspace.intents! {
                XCTAssertEqual(intent.intent, workspaceIntent.intent)
                XCTAssertEqual(intent.description, workspaceIntent.description)
                XCTAssertNotNil(intent.created)
                XCTAssertNotNil(intent.updated)
                XCTAssertNotNil(intent.examples)
                for example in intent.examples! {
                    XCTAssertNotNil(example.created)
                    XCTAssertNotNil(example.updated)
                    XCTAssertEqual(example.text, intentExample.text)
                }
            }
            
            XCTAssertNotNil(workspace.counterexamples)
            for counterexample in workspace.counterexamples! {
                XCTAssertNotNil(counterexample.created)
                XCTAssertNotNil(counterexample.updated)
                XCTAssertEqual(counterexample.text, workspaceCounterexample.text)
            }
            
            expectation2.fulfill()
        }
        waitForExpectations()
        
        let description3 = "Delete the newly created workspace."
        let expectation3 = expectation(description: description3)
        
        conversation.deleteWorkspace(workspaceID: newWorkspaceID, failure: failWithError) {
            expectation3.fulfill()
        }
        waitForExpectations()
    }
    
    func testListSingleWorkspace() {
        let description = "List details of a single workspace."
        let expectation = self.expectation(description: description)
        
        conversation.getWorkspace(workspaceID: workspaceID, export: false, failure: failWithError) { workspace in
            XCTAssertNotNil(workspace.name)
            XCTAssertNotNil(workspace.created)
            XCTAssertNotNil(workspace.updated)
            XCTAssertNotNil(workspace.language)
            XCTAssertNotNil(workspace.metadata)
            XCTAssertNotNil(workspace.workspaceID)
            XCTAssertNotNil(workspace.status)
            XCTAssertNil(workspace.intents)
            XCTAssertNil(workspace.entities)
            XCTAssertNil(workspace.counterexamples)
            XCTAssertNil(workspace.dialogNodes)
            expectation.fulfill()
        }
        waitForExpectations()
    }
    
    func testCreateUpdateAndDeleteWorkspace() {
        var newWorkspace: String?
        
        let description1 = "Create a workspace."
        let expectation1 = expectation(description: description1)
        
        let workspaceName = "swift-sdk-test-workspace"
        let workspaceDescription = "temporary workspace for the swift sdk unit tests"
        let workspaceLanguage = "en"
        let createWorkspaceBody = CreateWorkspace(name: workspaceName, description: workspaceDescription, language: workspaceLanguage)
        conversation.createWorkspace(body: createWorkspaceBody, failure: failWithError) { workspace in
            XCTAssertEqual(workspace.name, workspaceName)
            XCTAssertEqual(workspace.description, workspaceDescription)
            XCTAssertEqual(workspace.language, workspaceLanguage)
            XCTAssertNotNil(workspace.created)
            XCTAssertNotNil(workspace.updated)
            XCTAssertNotNil(workspace.workspaceID)
            
            newWorkspace = workspace.workspaceID
            expectation1.fulfill()
        }
        waitForExpectations()
        
        guard let newWorkspaceID = newWorkspace else {
            XCTFail("Failed to get the ID of the newly created workspace.")
            return
        }
        let description2 = "Update the newly created workspace."
        let expectation2 = expectation(description: description2)
        
        let newWorkspaceName = "swift-sdk-test-workspace-2"
        let newWorkspaceDescription = "new description for the temporary workspace"
        
        let updateWorkspaceBody = UpdateWorkspace(name: newWorkspaceName, description: newWorkspaceDescription)
        conversation.updateWorkspace(workspaceID: newWorkspaceID, body: updateWorkspaceBody, failure: failWithError) { workspace in
            XCTAssertEqual(workspace.name, newWorkspaceName)
            XCTAssertEqual(workspace.description, newWorkspaceDescription)
            XCTAssertEqual(workspace.language, workspaceLanguage)
            XCTAssertNotNil(workspace.created)
            XCTAssertNotNil(workspace.updated)
            XCTAssertNotNil(workspace.workspaceID)
            expectation2.fulfill()
        }
        waitForExpectations()
        
        let description3 = "Delete the newly created workspace."
        let expectation3 = expectation(description: description3)
        
        conversation.deleteWorkspace(workspaceID: newWorkspaceID, failure: failWithError) {
            expectation3.fulfill()
        }
        waitForExpectations()
    }

    // MARK: - Negative Tests

    func testMessageInvalidWorkspace() {
        let description = "Start a conversation with an invalid workspace."
        let expectation = self.expectation(description: description)
        
        let workspaceID = "this-id-is-invalid"
        let failure = { (error: Error) in
            expectation.fulfill()
        }
        
        conversation.message(withWorkspace: workspaceID, failure: failure, success: failWithResult)
        waitForExpectations()
    }
}
