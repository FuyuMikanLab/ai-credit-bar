import Foundation
import Darwin

/// 离线自测：`./AICreditBar --selftest`
/// 用各家接口的样例响应验证 Adapter 解析逻辑（不发网络请求）。
enum SelfTest {
    static func run() {
        print("== \(AppIdentity.name) 自测 ==")
        var failed = 0
        var passed = 0

        func check(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                passed += 1
                print("  ✓ \(name)")
            } catch {
                failed += 1
                print("  ✗ \(name): \(error)")
            }
        }

        func obj(_ json: String) throws -> Any {
            guard let data = json.data(using: .utf8) else { throw AdapterError.emptyData("JSON 编码失败") }
            return try JSONSerialization.jsonObject(with: data)
        }

        // MARK: 注册表
        check("注册表包含 6 个适配器") {
            let kinds = Set(ProviderRegistry.all.map(\.kind))
            guard kinds.count == 6 else { throw AdapterError.emptyData("数量不对: \(kinds.count)") }
        }

        // MARK: DeepSeek
        check("DeepSeek 解析") {
            let raw = try obj("""
            {"is_available": true, "balance_infos": [
              {"currency": "CNY", "total_balance": "110.00", "granted_balance": "10.00", "topped_up_balance": "100.00"}
            ]}
            """)
            let m = try DeepSeekAdapter.parse(raw, now: Date())
            guard m.availableBalance == Decimal(string: "110"), m.currency == "CNY" else {
                throw AdapterError.emptyData("余额/币种不对: \(m)")
            }
            // 断言与语言无关：详情行里必然包含充值金额 ¥100（赠送 ¥10 · 充值 ¥100）。
            guard m.detailLines.first?.contains("¥100") == true else { throw AdapterError.emptyData("缺少充值明细") }
        }

        // MARK: Moonshot
        check("Moonshot(CN) 解析") {
            let raw = try obj("""
            {"code": 0, "data": {"available_balance": 49.58894, "voucher_balance": 46.58893, "cash_balance": 3.00001}, "status": true}
            """)
            let base = URL(string: "https://api.moonshot.cn")!
            let m = try MoonshotAdapter.parse(raw, baseURL: base, now: Date())
            guard let bal = m.availableBalance, bal > 49, bal < 50, m.currency == "CNY" else {
                throw AdapterError.emptyData("余额/币种不对: \(m)")
            }
        }

        // MARK: OpenRouter
        check("OpenRouter 解析") {
            let raw = try obj("""
            {"data": {"total_credits": 100, "total_usage": 42.5}}
            """)
            let m = try OpenRouterAdapter.parse(raw, now: Date())
            guard let avail = m.availableBalance, avail == Decimal(string: "57.5"),
                  m.cycleUsed == Decimal(string: "42.5"), m.totalCredits == Decimal(string: "100") else {
                throw AdapterError.emptyData("额度计算不对: \(m)")
            }
        }

        // MARK: SiliconFlow
        check("SiliconFlow 新版 data.totalBalance 解析") {
            let raw = try obj("""
            {"data": {"totalBalance": 12.34, "name": "tester"}}
            """)
            let base = URL(string: "https://api.siliconflow.cn")!
            let m = try SiliconFlowAdapter.parse(raw, baseURL: base, now: Date())
            guard m.availableBalance == Decimal(string: "12.34"), m.currency == "CNY" else {
                throw AdapterError.emptyData("余额/币种不对: \(m)")
            }
        }
        check("SiliconFlow 旧版顶层 balance(字符串) 解析") {
            let raw = try obj("""
            {"id": "u1", "name": "tester", "balance": "3.25"}
            """)
            let base = URL(string: "https://api.siliconflow.cn")!
            let m = try SiliconFlowAdapter.parse(raw, baseURL: base, now: Date())
            guard m.availableBalance == Decimal(string: "3.25") else {
                throw AdapterError.emptyData("余额不对: \(m)")
            }
        }

        // MARK: OpenAI
        check("OpenAI 本月用量聚合") {
            let raw = try obj("""
            {"data": [
              {"start_time": 1, "end_time": 2, "results": [
                {"input_tokens": 100, "output_tokens": 200, "num_model_requests": 5},
                {"input_tokens": 50, "output_tokens": 10, "num_model_requests": 1}
              ]}
            ], "has_more": false}
            """)
            let m = try OpenAIAdapter.parse(raw, now: Date())
            guard m.inputTokens == 150, m.outputTokens == 210, m.requests == 6 else {
                throw AdapterError.emptyData("聚合不对: \(m)")
            }
        }

        // MARK: 智谱
        check("智谱 legacy balance 解析") {
            let raw = try obj("""
            {"balance": [{"total": 50.01, "used": 0.01}], "code": 200, "msg": "ok"}
            """)
            let m = try ZhipuAdapter.parseLegacy(raw, now: Date())
            guard let avail = m.availableBalance, avail == Decimal(string: "50"),
                  m.totalCredits == Decimal(string: "50.01") else {
                throw AdapterError.emptyData("余额计算不对: \(m)")
            }
        }
        check("智谱 biz 账户报表解析") {
            let raw = try obj("""
            {"data": {"availableBalance": 11.2, "rechargeAmount": 100, "totalSpendAmount": 88.8, "giveAmount": 5.0}}
            """)
            let m = try ZhipuAdapter.parseBiz(raw, now: Date())
            guard m.availableBalance == Decimal(string: "11.2"),
                  m.cycleUsed == Decimal(string: "88.8"),
                  m.totalCredits == Decimal(string: "100") else {
                throw AdapterError.emptyData("报表解析不对: \(m)")
            }
        }

        // MARK: 金额格式化
        check("金额格式化") {
            guard Money.short(Decimal(string: "110")!, currency: "CNY") == "¥110" else { throw AdapterError.emptyData("short") }
            guard Money.two(Decimal(string: "49.58894")!, currency: "USD") == "$49.59" else { throw AdapterError.emptyData("two") }
        }

        print("== 结果：\(passed) 通过，\(failed) 失败 ==")
        exit(failed == 0 ? 0 : 1)
    }
}
