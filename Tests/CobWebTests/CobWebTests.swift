@testable import CobWeb
import VaporTesting
import Testing
import Crumbs

@Suite("App Tests with DB")
struct CobWebTests {
    static func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
    
    private struct Setup {
        static func user(app: Application, name: String = "Test", email: String? = nil, password: String = "Test123") async throws -> (userId: UUID, token: TokenDTO) {
            
            var userDTO: UserDTO?
            
            let finalEmail: String = email ?? "\(name)@test.com"
            
            try await app.test(.POST, "/users/signup") { req in
                try req.content.encode(User.Create.init(
                    name: name,
                    email: finalEmail,
                    password: password,
                    confirmPassword: password
                ))
            } afterResponse: { res in
                #expect(res.status == .ok)
                userDTO = try JSONDecoder().decode(UserDTO.self, from: res.body)
            }
            
            guard
                let userDTO,
                let userId = try await User.query(on: app.db).filter(\.$email, .equal, userDTO.email).first()?.requireID()
            else { Issue.record("Failed to create user"); throw Abort(.expectationFailed) }
            
            var tokenDTO: TokenDTO?
            try await app.test(.POST, "/users/login") { req in
                let raw = "\(finalEmail):\(password)"
                let encoded = Data(raw.utf8).base64EncodedString()
                
                req.headers.replaceOrAdd(name: .authorization, value: "Basic \(encoded)")
            } afterResponse: { res async throws in
                #expect(res.status == .ok)
                tokenDTO = try res.content.decode(UserTokenDTO.self).token
            }
            
            guard let tokenDTO
            else { Issue.record("Failed to get token"); throw Abort(.expectationFailed) }
            
            return (userId, tokenDTO)
        }
        
        @discardableResult
        static func cobOrder(app: Application, userId: UUID, weekDTO: WeekDTO, detailDTO: CobOrderDetailDTO) async throws -> UUID {
            guard let week = weekDTO.date
            else { throw Abort(.internalServerError) }
            
            let orderDetail: CobOrderDetail = .init(from: detailDTO)
            
            let order = CobOrder(week: week, orderDetail: orderDetail, userId: userId)
            
            try await order.create(on: app.db)
            
            return try order.requireID()
        }
        
        @discardableResult
        static func recurringOrder(app: Application, userId: UUID, startWeek: WeekDTO, detailDTO: CobOrderDetailDTO) async throws -> UUID {
            let orderDetail = CobOrderDetail(from: detailDTO)
            
            let order = RecurringOrder(userId: userId, startAt: startWeek.date ?? Date.distantPast, orderDetail: orderDetail)
            
            try await order.create(on: app.db)
            
            return try order.requireID()
        }
        
        @discardableResult
        static func recurringOrderException(app: Application, userId: UUID, weekDTO: WeekDTO) async throws -> UUID {
            guard let weekDate = weekDTO.date
            else { throw Abort(.expectationFailed) }
            let exception = RecurringOrderException(week: weekDate, userId: userId)
            
            try await exception.create(on: app.db)
            
            return try exception.requireID()
        }

        static func history(app: Application, userId: UUID, weeklyOrders: [WeekDTO:CobOrderDetailDTO]) async throws {
            let orders = try weeklyOrders.map {
                guard let week = $0.key.date
                else { throw Abort(.internalServerError) }
                
                let orderDetail = CobOrderDetail(from: $0.value)
                return CobOrder(week: week, orderDetail: orderDetail, userId: userId)
            }
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for order in orders {
                    group.addTask {
                        try await order.create(on: app.db)
                    }
                }
                try await group.waitForAll()
            }
        }
    }
    
    
    
    @Suite("User API Tests")
    struct UserAPITests {
        
        @Test("Signup")
        func testSignup() async throws {
            try await withApp { app in
                let user = UserDTO(name: "Test", email: "test@test.com")
                let password = "Test123"
                
                try await app.test(.POST, "/users/signup") { req in
                    try req.content.encode(User.Create.init(
                        name: user.name,
                        email: user.email,
                        password: password,
                        confirmPassword: password
                    ))
                } afterResponse: { res in
                    #expect(res.status == .ok)
                    let userDTO = try JSONDecoder().decode(UserDTO.self, from: res.body)
                    #expect(userDTO.name == user.name)
                    #expect(userDTO.email == user.email)
                }
            }
        }
        
        @Test("Login")
        func testLogin() async throws {
            try await withApp { app in
                let name = "Test"
                let email = "test@test.com"
                let password = "Test123"
                let passwordHash = try Bcrypt.hash(password)
                
                try await User(name: name, email: email, passwordHash: passwordHash).create(on: app.db)
                
                try await app.test(.POST, "/users/login") { req in
                    let raw = "\(email):\(password)"
                    let encoded = Data(raw.utf8).base64EncodedString()
                    
                    req.headers.replaceOrAdd(name: .authorization, value: "Basic \(encoded)")
                } afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let tokenDTO = try res.content.decode(UserTokenDTO.self).token
                    #expect(!tokenDTO.value.isEmpty)
                }
            }
        }
    }
    
    @Suite("Public API Tests")
    struct PublicAPITests {
        
        @Test("Empty")
        func testEmpty() async throws {
            try await withApp { app in
                // MARK: Setup Environment
                let (_, _) = try await Setup.user(app: app)
                let weekDTO: WeekDTO = .current
                
                // MARK: Test API
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res in
                    #expect(res.status == .ok)
                    
                    let ordersData = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    // Current week
                    #expect(ordersData.week == weekDTO)
                    
                    // No cob orders
                    #expect(ordersData.orders.isEmpty)
                }
            }
        }
        
        @Test("Single User Single Order")
        func testSingleUserSingleOrder() async throws {
            try await withApp { app in
                // MARK: Setup Environment
                let (userId, token) = try await Setup.user(app: app)
                let weekDTO: WeekDTO = .current
                
                
                let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                let orderId = try await Setup.cobOrder(app: app, userId: userId, weekDTO: weekDTO, detailDTO: detailDTO)
                
                // MARK: Test API
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                    req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                } afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    
                    #expect(weekWithOrders.orders.count == 1)
                    
                    #expect(weekWithOrders.orders.first?.orderDetail == detailDTO)
                    
                    #expect(weekWithOrders.orders.first?.id == orderId)
                    
                    #expect(weekWithOrders.orders.first?.orderKind == .single)
                }
            }
        }
        
        @Test("Single User Excepted Order")
        func testSingleUserExceptedOrder() async throws {
            try await withApp { app in
                
                // MARK: Setup Environment
                let (userId, _) = try await Setup.user(app: app)
                let weekDTO: WeekDTO = .current
            
                let recurringDetailDTO = CobOrderDetailDTO(filling: .sausage, bread: .white, sauce: .red)
                
                let exceptedOrderId = try await Setup.recurringOrderException(app: app, userId: userId, weekDTO: weekDTO)
                let recurringOrderId = try await Setup.recurringOrder(app: app, userId: userId, startWeek: weekDTO, detailDTO: recurringDetailDTO)
                
                // MARK: Test API (with Excepted Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                     
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 0)
                }
                
                // MARK: Delete Single Order
                try await RecurringOrderException.query(on: app.db).filter(\RecurringOrderException.$id, .equal, exceptedOrderId).delete()
                
                // MARK: Test API (with Recurring Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 1)
                    
                    #expect(weekWithOrders.orders.first?.id == recurringOrderId)
                    #expect(weekWithOrders.orders.first?.orderKind == .recurring)
                    #expect(weekWithOrders.orders.first?.orderDetail == recurringDetailDTO)
                }
            }
        }
        
        @Test("Single User Multiple Orders")
        func testSingleUserMultipleOrders() async throws {
            try await withApp { app in
                
                // MARK: Setup Environment
                let (userId, _) = try await Setup.user(app: app)
                let weekDTO: WeekDTO = .current
                
                let singleDetailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                let recurringDetailDTO = CobOrderDetailDTO(filling: .sausage, bread: .white, sauce: .red)
                
                let singleOrderId = try await Setup.cobOrder(app: app, userId: userId, weekDTO: weekDTO, detailDTO: singleDetailDTO)
                let recurringOrderId = try await Setup.recurringOrder(app: app, userId: userId, startWeek: weekDTO, detailDTO: recurringDetailDTO)
                
                // MARK: Test API (with Single Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 1)
                    
                    #expect(weekWithOrders.orders.first?.id == singleOrderId)
                    #expect(weekWithOrders.orders.first?.orderKind == .single)
                    #expect(weekWithOrders.orders.first?.orderDetail == singleDetailDTO)
                }
                
                // MARK: Delete Single Order
                try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, singleOrderId).delete()
                
                // MARK: Test API (with Recurring Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 1)
                
                    #expect(weekWithOrders.orders.first?.id == recurringOrderId)
                    #expect(weekWithOrders.orders.first?.orderKind == .recurring)
                    #expect(weekWithOrders.orders.first?.orderDetail == recurringDetailDTO)
                }
            }
        }
        
        @Test("Multiple Users Multiple Orders")
        func testMultipleUsersMultipleOrders() async throws {
            try await withApp { app in
                
                // MARK: Setup Environment
                let (userId1, _) = try await Setup.user(app: app, name: "User1")
                let (userId2, _) = try await Setup.user(app: app, name: "User2")
                let weekDTO: WeekDTO = .current
                
                let singleDetailDTO1 = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                let singleDetailDTO2 = CobOrderDetailDTO(filling: .egg, bread: .brown, sauce: .brown)
                let recurringDetailDTO = CobOrderDetailDTO(filling: .sausage, bread: .white, sauce: .red)
                
                let singleOrderId1 = try await Setup.cobOrder(app: app, userId: userId1, weekDTO: weekDTO, detailDTO: singleDetailDTO1)
                let singleOrderId2 = try await Setup.cobOrder(app: app, userId: userId2, weekDTO: weekDTO, detailDTO: singleDetailDTO2)
                let recurringOrderId = try await Setup.recurringOrder(app: app, userId: userId1, startWeek: weekDTO, detailDTO: recurringDetailDTO)
                
                // MARK: Test API (with Single Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 2)
                    
                    let sortedOrders = weekWithOrders.orders.sorted { $0.name < $1.name }
                    
                    #expect(sortedOrders.first?.id == singleOrderId1)
                    #expect(sortedOrders.first?.orderKind == .single)
                    #expect(sortedOrders.first?.orderDetail == singleDetailDTO1)
                    
                    #expect(sortedOrders.last?.id == singleOrderId2)
                    #expect(sortedOrders.last?.orderKind == .single)
                    #expect(sortedOrders.last?.orderDetail == singleDetailDTO2)
                }
                
                // MARK: Delete Single Order
                try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, singleOrderId1).delete()
                
                // MARK: Test API (with Recurring Order)
                try await app.test(.GET, "/orders?week=\(weekDTO.week)&year=\(weekDTO.year)") { res async throws in
                    #expect(res.status == .ok)
                    
                    let weekWithOrders = try res.content.decode(WeekDTO.WeeklyOrderDTO.self)
                    
                    #expect(weekWithOrders.week == weekDTO)
                    #expect(weekWithOrders.orders.count == 2)
                    
                    let sortedOrders = weekWithOrders.orders.sorted { $0.name < $1.name }
                
                    #expect(sortedOrders.first?.id == recurringOrderId)
                    #expect(sortedOrders.first?.orderKind == .recurring)
                    #expect(sortedOrders.first?.orderDetail == recurringDetailDTO)
                    
                    #expect(sortedOrders.last?.id == singleOrderId2)
                    #expect(sortedOrders.last?.orderKind == .single)
                    #expect(sortedOrders.last?.orderDetail == singleDetailDTO2)
                }
            }
        }
    }
    
    @Suite("Private")
    struct PrivateAPITests {
        
        @Suite("Single")
        struct SingleAPITests {
            
            @Suite("GET")
            struct GetOrder {
                
                @Test("Regular")
                func testStandardOrder() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let (userId, token) = try await Setup.user(app: app)
                        try await Setup.cobOrder(app: app, userId: userId, weekDTO: weekDTO, detailDTO: detailDTO)
                        
                        // MARK: Test API
                        try await app.test(.GET, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                            
                            let orderWithWeek = try res.content.decode(CobOrderDTO.AssociatedWeek.self)
                            
                            #expect(orderWithWeek.week == weekDTO)
                            
                            #expect(orderWithWeek.order.orderDetail == detailDTO)
                        }
                    }
                }
                
                @Test("Missing")
                func testNonExistentOrder() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        
                        let (_, token) = try await Setup.user(app: app)
                        
                        // MARK: Test API
                        try await app.test(.GET, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .notFound)
                        }
                    }
                }
            }
            
            @Suite("POST")
            struct PlaceOrder {
                
                @Test("Place Order")
                func testPlaceOrder() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let (userId, token) = try await Setup.user(app: app)
                        
                        // MARK: Test API
                        try await app.test(.POST, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                            req.headers.replaceOrAdd(name: .contentType, value: "application/json")
                            try req.body.writeJSONEncodable(detailDTO, encoder: JSONEncoder())
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                        }
                        
                        guard let order = try await CobOrder.query(on: app.db).filter(\CobOrder.$user.$id, .equal, userId).first()
                        else { Issue.record("Failed to fetch created order"); return }
                        
                        let orderDTO = try CobOrderDTO(fromOrder: order)
                        
                        #expect(orderDTO.orderDetail == detailDTO)
                    }
                }
            }
            
            @Suite("DELETE")
            struct DeleteOrder {
                
                @Test("Regular (using id)")
                func testDeleteOrderWithId() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let (userId, token) = try await Setup.user(app: app)
                        
                        let orderId = try await Setup.cobOrder(app: app, userId: userId, weekDTO: weekDTO, detailDTO: detailDTO)
                        
                        // Test Existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 1)
                        
                        guard let orderId = try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).first()?.requireID()
                        else { Issue.record("OrderId not found"); return }
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me?id=\(orderId)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                        }
                        
                        // Test Non-existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 0)
                    }
                }
                
                @Test("Regular (using week)")
                func testDeleteOrderWithWeek() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let (userId, token) = try await Setup.user(app: app)
                        
                        let orderId = try await Setup.cobOrder(app: app, userId: userId, weekDTO: weekDTO, detailDTO: detailDTO)
                        
                        // Test Existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 1)
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                        }
                        
                        // Test Non-existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 0)
                    }
                }
                
                @Test("Missing (using id)")
                func testDeleteMissingOrderWithId() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        
                        let (_, token) = try await Setup.user(app: app)
                        
                        let orderId = UUID()
                        
                        // Test Existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 0)
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .notFound)
                        }
                    }
                }
                
                @Test("Missing (using week)")
                func testDeleteMissingWithWeek() async throws {
                    try await withApp { app in
                        
                        // MARK: Setup Environment
                        let weekDTO: WeekDTO = .current
                        
                        let (_, token) = try await Setup.user(app: app)
                        
                        let orderId = UUID()
                        
                        // Test Existence in DB
                        #expect(try await CobOrder.query(on: app.db).filter(\CobOrder.$id, .equal, orderId).count() == 0)
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .notFound)
                        }
                    }
                }
            }
        }
        
        @Suite("Recurring")
        struct RecurringAPITests {
            @Suite("GET")
            struct GetOrder {
                @Test("Regular")
                func testRecurringOrder() async throws {
                    try await withApp { app in
                        let (userId, token) = try await Setup.user(app: app, name: "User")
                        let weekDTO: WeekDTO = .current
                        let orderDetail = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let recurringOrderId = try await Setup.recurringOrder(app: app, userId: userId, startWeek: weekDTO, detailDTO: orderDetail)
                        
                        try await app.test(.GET, "/orders/me/recurring") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res in
                            #expect(res.status == .ok)
                            
                            let recurringOrder = try res.content.decode(RecurringOrderDTO.AssociatedName.self)
                            
                            #expect(recurringOrder.id == recurringOrderId)
                            #expect(recurringOrder.name == "User")
                            #expect(recurringOrder.orderDetail == orderDetail)
                        }
                    }
                }
                
                @Test("Missing")
                func testNoRecurringOrder() async throws {
                    try await withApp { app in
                        let (_, token) = try await Setup.user(app: app)
                        
                        try await app.test(.GET, "/orders/me/recurring") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res in
                            #expect(res.status == .notFound)
                        }
                    }
                }
            }
            
            @Suite("POST")
            struct PlaceOrder {
                @Test("Regular")
                func testRecurringOrder() async throws {
                    try await withApp { app in
                        let (userId, token) = try await Setup.user(app: app, name: "User")
                        let weekDTO: WeekDTO = .current
                        let orderDetail = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        try await app.test(.POST, "/orders/me/recurring?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                            req.headers.replaceOrAdd(name: .contentType, value: "application/json")
                            try req.body.writeJSONEncodable(orderDetail)
                        } afterResponse: { res in
                            #expect(res.status == .ok)
                            
                            let recurringOrder = try res.content.decode(RecurringOrderDTO.AssociatedName.self)
                            
                            #expect(recurringOrder.name == "User")
                            #expect(recurringOrder.orderDetail == orderDetail)
                        }
                        
                        let recurringOrder = try await RecurringOrder.query(on: app.db).filter(\RecurringOrder.$user.$id, .equal, userId).first()
                        
                        #expect((recurringOrder?.orderDetail).map(CobOrderDetailDTO.init(fromDetail:)) == orderDetail)
                    }
                }
                
                @Test("Overwrite")
                func testOverwriteRecurringOrder() async throws {
                    try await withApp { app in
                        let (userId, token) = try await Setup.user(app: app)
                        guard let weekDTO1: WeekDTO = .current.subtract(weeks: 2)
                        else { Issue.record("Failed to calculate prior week date"); return }
                        let weekDTO2: WeekDTO = .current
                        let orderDetail1 = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        let orderDetail2 = CobOrderDetailDTO(filling: .sausage, bread: .white, sauce: .red)
                        
                        let initialRecurringOrderId = try await Setup.recurringOrder(app: app, userId: userId, startWeek: weekDTO1, detailDTO: orderDetail1)
                        
                        // MARK: Test API
                        try await app.test(.POST, "/orders/me/recurring?week=\(weekDTO2.week)&year=\(weekDTO2.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                            req.headers.replaceOrAdd(name: .contentType, value: "application/json")
                            try req.body.writeJSONEncodable(orderDetail2)
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                            
                            let overwriteRecurring = try res.content.decode(RecurringOrderDTO.AssociatedName.self)
                            
                            #expect(overwriteRecurring.id == initialRecurringOrderId)
                            #expect(overwriteRecurring.startWeek == weekDTO2)
                            #expect(overwriteRecurring.orderDetail == orderDetail2)
                        }
                        
                        let dbRecurringOrder = try await RecurringOrder.query(on: app.db).filter(\RecurringOrder.$user.$id, .equal, userId).first()
                        
                        #expect((dbRecurringOrder?.orderDetail).map(CobOrderDetailDTO.init(fromDetail:)) == orderDetail2)
                        #expect(dbRecurringOrder?.startAt == weekDTO2.date)
                    }
                }
            }
            
            @Suite("DELETE")
            struct DeleteOrder {
                @Test("Regular")
                func testDeleteRecurring() async throws {
                    try await withApp { app in
                        let (userId, token) = try await Setup.user(app: app)
                        let weekDTO: WeekDTO = .current
                        let detailDTO = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .brown)
                        
                        let initialRecurringOrderId = try await Setup.recurringOrder(app: app, userId: userId, startWeek: weekDTO, detailDTO: detailDTO)
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me/recurring?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .ok)
                        }
                        
                        #expect(try await RecurringOrder.query(on: app.db).filter(\RecurringOrder.$id, .equal, initialRecurringOrderId).count() == 0)
                    }
                }
                
                @Test("Missing")
                func testDeleteNonExistentRecurring() async throws {
                    try await withApp { app in
                        let (_, token) = try await Setup.user(app: app)
                        let weekDTO: WeekDTO = .current
                        
                        // MARK: Test API
                        try await app.test(.DELETE, "/orders/me/recurring?week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                            req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                        } afterResponse: { res async throws in
                            #expect(res.status == .notFound)
                        }
                    }
                }
            }
        }
        
        @Suite("History")
        struct HistoryAPITests {
            @Test("Empty")
            func testEmptyHistory() async throws {
                try await withApp { app in
                    
                    // MARK: Setup Environment
                    let (_, token) = try await Setup.user(app: app)
                    let weekDTO: WeekDTO = .current
                    
                    // MARK: Test API
                    try await app.test(.GET, "/orders/me/history?page=0&week=\(weekDTO.week)&year=\(weekDTO.year)") { req in
                        req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                    } afterResponse: { res async throws in
                        #expect(res.status == .ok)
                        
                        let historyData = try res.content.decode([WeekDTO.AssociatedOrderDTO].self)
                        
                        // No cob orders
                        #expect(historyData.compactMap(\.order).isEmpty)
                        
                        // 10 weeks per page
                        #expect(historyData.count == 10)
                        
                        guard let latestHistoryWeek = historyData.max(count: 1, sortedBy: { $0.week < $1.week }).first
                        else { Issue.record("No weeks in history"); return }
                        
                        guard let lastWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())
                        else { Issue.record("Failed to calculate last week date"); return }
                        
                        let lastWeek = WeekDTO(from: lastWeekDate)
                        
                        // Most recent week is current week
                        #expect(latestHistoryWeek.week == lastWeek)
                    }
                }
            }
            
            @Test("Single Week")
            func testSingleWeek() async throws {
                try await withApp { app in
                    // MARK: Constants Initialisation
                    guard let lastWeek = WeekDTO.current.add(weeks: -1)
                    else { Issue.record("Failed to calculate week dependency"); return }
                    let weekOrder = CobOrderDetailDTO(filling: .bacon, bread: .brown, sauce: .red)
                    
                    // MARK: Environment Setup
                    let (userId, token) = try await Setup.user(app: app)
                    try await Setup.history(app: app, userId: userId, weeklyOrders: [lastWeek:weekOrder])
                    
                    // MARK: Test API
                    try await app.test(.GET, "/orders/me/history?page=0") { req in
                        req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                    } afterResponse: { res async throws in
                        #expect(res.status == .ok)
                        let historyData = try res.content.decode([WeekDTO.AssociatedOrderDTO].self)
                        
                        // 10 weeks per page
                        #expect(historyData.count == 10)
                        
                        // No cob orders
                        #expect(historyData.compactMap(\.order).count == 1)
                        
                        guard let latestHistoryWeek = historyData.max(count: 1, sortedBy: { $0.week < $1.week }).first
                        else { Issue.record("No weeks in history"); return }
                        
                        guard let lastWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())
                        else { Issue.record("Failed to calculate last week date"); return }
                        
                        let lastWeek = WeekDTO(from: lastWeekDate)
                        
                        // Most recent week is current week
                        #expect(latestHistoryWeek.week == lastWeek)
                        
                        // Most recent week contains order
                        guard case .single(let orderDetail) = latestHistoryWeek.order
                        else { Issue.record("Latest week in history should contain a single order"); return }
                        #expect(orderDetail == weekOrder)
                    }
                }
            }
            
            @Test("Multi-Week Orders")
            func testMultipleWeekOrders() async throws {
                try await withApp { app in
                    // MARK: Constants Initialisation
                    guard
                        let orderWeek = WeekDTO.current.add(weeks: -2),
                        let exceptionWeek = WeekDTO.current.add(weeks: -3),
                        let recurringWeek = WeekDTO.current.add(weeks: -5),
                        let emptyWeek = WeekDTO.current.add(weeks: -6)
                    else { throw Abort(.expectationFailed) }
                    
                    let order = CobOrderDetailDTO(filling: .bacon, bread: .white, sauce: .red)
                    let recurringOrder = CobOrderDetailDTO(filling: .vegan_sausage, bread: .brown, sauce: .brown)
                    
                    // MARK: Environment Setup
                    let (userId, token) = try await Setup.user(app: app)
                    try await Setup.cobOrder(app: app, userId: userId, weekDTO: orderWeek, detailDTO: order)
                    try await Setup.recurringOrder(app: app, userId: userId, startWeek: recurringWeek, detailDTO: recurringOrder)
                    try await Setup.recurringOrderException(app: app, userId: userId, weekDTO: exceptionWeek)
                    
                    // MARK: Test API
                    try await app.test(.GET, "/orders/me/history?page=0") { req in
                        req.headers.replaceOrAdd(name: .authorization, value: "Bearer \(token.value)")
                    } afterResponse: { res async throws in
                        #expect(res.status == .ok)
                        let historyData = try res.content.decode([WeekDTO.AssociatedOrderDTO].self)
                        
                        // 10 weeks per page
                        #expect(historyData.count == 10)
                        
                        // No cob orders
                        #expect(historyData.compactMap(\.order).count == 5)
                        
                        // Check one-off order
                        #expect(historyData
                            .filter { $0.week == orderWeek }
                            .first?.order?.orderDetail == order)
                        
                        // Check recurring order
                        #expect(historyData
                            .filter { $0.week != orderWeek && $0.week != exceptionWeek }
                            .compactMap(\.order)
                            .allSatisfy { $0.orderDetail == recurringOrder })
                        
                        // Check exception week has .exception order
                        #expect(historyData
                            .filter { $0.week == exceptionWeek }
                            .first?.order == .exception)
                        
                        // Check recurring week has .recurring order
                        #expect(historyData
                            .filter { $0.week == recurringWeek }
                            .first?.order == .recurring(recurringOrder))
                        
                        // Check pre-recurring weeks have nil orders
                        #expect(historyData
                            .filter { $0.week == emptyWeek }
                            .first?.order == nil)
                    }
                }
            }
        }
    }
}
