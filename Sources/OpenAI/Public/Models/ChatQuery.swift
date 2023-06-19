//
//  ChatQuery.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 02/04/2023.
//

import Foundation

public struct Chat: Codable {
    public struct FunctionCall: Codable {
        public let name: String
        public let arguments: [String: Any]?

        private enum CodingKeys: String, CodingKey {
            case name
            case arguments
        }

        init(name: String, arguments: [String: Any]?) {
            self.name = name
            self.arguments = arguments
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.arguments = container.decodeIfPresent([String: Any].self, forKey: .arguments)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)
            if let arguments = self.arguments {
                try container.encode(arguments, forKey: .arguments)
            }
        }
    }

    public let role: Role
    public let content: String?
    public let name: String?
    public let functionCall: FunctionCall?

    public enum Role: String, Codable, Equatable {
        case system
        case assistant
        case user
        case function
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case functionCall = "function_call"
    }

    public init(role: Role, name: String?=nil, content: String?, functionCall: FunctionCall?=nil) {
        self.role = role
        self.name = name
        self.content = content
        self.functionCall = functionCall
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(Role.self, forKey: .role)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.functionCall = try container.decodeIfPresent(FunctionCall.self, forKey: .functionCall)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.role, forKey: .role)
        try container.encodeIfPresent(self.content, forKey: .content)
        try container.encodeIfPresent(self.name, forKey: .name)
        try container.encodeIfPresent(self.functionCall, forKey: .functionCall)
    }
}

public struct ChatQuery: Codable, Streamable {
    public enum FunctionCall: Codable, Equatable {
        case none
        case auto
        case function(name: String)

        enum CodingKeys: CodingKey {
            case none
            case auto
            case function
        }

        enum FunctionCodingKeys: CodingKey {
            case name
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ChatQuery.FunctionCall.CodingKeys.self)
            var allKeys = ArraySlice(container.allKeys)
            guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                throw DecodingError.typeMismatch(ChatQuery.FunctionCall.self, DecodingError.Context.init(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
            }
            switch onlyKey {
            case .function:
                let nestedContainer = try container.nestedContainer(keyedBy: ChatQuery.FunctionCall.FunctionCodingKeys.self, forKey: ChatQuery.FunctionCall.CodingKeys.function)
                self = ChatQuery.FunctionCall.function(name: try nestedContainer.decode(String.self, forKey: ChatQuery.FunctionCall.FunctionCodingKeys.name))

            default:
                fatalError()
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: ChatQuery.FunctionCall.CodingKeys.self)
            switch self {
            case .function(let name):
                var nestedContainer = container.nestedContainer(keyedBy: ChatQuery.FunctionCall.FunctionCodingKeys.self, forKey: ChatQuery.FunctionCall.CodingKeys.function)
                try nestedContainer.encode(name, forKey: ChatQuery.FunctionCall.FunctionCodingKeys.name)

            default:
                break
            }
        }
    }

    public struct Function: Codable {
        let name: String
        let functionDescription: String?
        let parameters: [String: Any]?

        enum CodingKeys: String, CodingKey {
            case name
            case functionDescription = "description"
            case parameters
        }

        public init(name: String, description: String? = nil, parameters: [String: Any]?) {
            self.name = name
            self.functionDescription = description
            self.parameters = parameters
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.functionDescription = try container.decodeIfPresent(String.self, forKey: .functionDescription)
            self.parameters = container.decodeIfPresent([String: Any].self, forKey: .parameters)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.name, forKey: .name)
            try container.encode(self.functionDescription, forKey: .functionDescription)
            if let parameters = self.parameters {
                try container.encode(parameters, forKey: .parameters)
            }
        }
    }

    /// ID of the model to use. Currently, only gpt-3.5-turbo and gpt-3.5-turbo-0301 are supported.
    public let model: Model
    /// The messages to generate chat completions for
    public let messages: [Chat]
    /// What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and  We generally recommend altering this or top_p but not both.

    public let functions: [Function]?
    public let functionCall: FunctionCall?

    public let temperature: Double?
    /// An alternative to sampling with temperature, called nucleus sampling, where the model considers the results of the tokens with top_p probability mass. So 0.1 means only the tokens comprising the top 10% probability mass are considered.
    public let topP: Double?
    /// How many chat completion choices to generate for each input message.
    public let n: Int?
    /// Up to 4 sequences where the API will stop generating further tokens. The returned text will not contain the stop sequence.
    public let stop: [String]?
    /// The maximum number of tokens to generate in the completion.
    public let maxTokens: Int?
    /// Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
    public let presencePenalty: Double?
    /// Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
    public let frequencyPenalty: Double?
    /// Modify the likelihood of specified tokens appearing in the completion.
    public let logitBias: [String:Int]?
    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    public let user: String?
    
    var stream: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case functions
        case functionCall = "function_call"
        case temperature
        case topP = "top_p"
        case n
        case stream
        case stop
        case maxTokens = "max_tokens"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case user
    }
    
    public init(model: Model, messages: [Chat], functions: [Function]? = nil, functionCall: FunctionCall? = nil, temperature: Double? = nil, topP: Double? = nil, n: Int? = nil, stop: [String]? = nil, maxTokens: Int? = nil, presencePenalty: Double? = nil, frequencyPenalty: Double? = nil, logitBias: [String : Int]? = nil, user: String? = nil) {
        self.model = model
        self.messages = messages
        self.functions = functions
        self.functionCall = functionCall
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stop = stop
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.user = user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decode(Model.self, forKey: .model)
        self.messages = try container.decode([Chat].self, forKey: .messages)
        self.functions = try container.decodeIfPresent([ChatQuery.Function].self, forKey: .functions)
        self.functionCall = try container.decode(ChatQuery.FunctionCall.self, forKey: .functionCall)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        self.n = try container.decodeIfPresent(Int.self, forKey: .n)
        self.stream = try container.decode(Bool.self, forKey: .stream)
        self.stop = try container.decodeIfPresent([String].self, forKey: .stop)
        self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        self.presencePenalty = try container.decodeIfPresent(Double.self, forKey: .presencePenalty)
        self.frequencyPenalty = try container.decodeIfPresent(Double.self, forKey: .frequencyPenalty)
        self.logitBias = try container.decodeIfPresent([String : Int].self, forKey: .logitBias)
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.model, forKey: .model)
        try container.encode(self.messages, forKey: .messages)
        try container.encodeIfPresent(self.functions, forKey: .functions)
        try container.encodeIfPresent(self.temperature, forKey: .temperature)
        try container.encodeIfPresent(self.topP, forKey: .topP)
        try container.encodeIfPresent(self.n, forKey: .n)
        try container.encode(self.stream, forKey: .stream)
        try container.encodeIfPresent(self.stop, forKey: .stop)
        try container.encodeIfPresent(self.maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(self.presencePenalty, forKey: .presencePenalty)
        try container.encodeIfPresent(self.frequencyPenalty, forKey: .frequencyPenalty)
        try container.encodeIfPresent(self.logitBias, forKey: .logitBias)
        try container.encodeIfPresent(self.user, forKey: .user)

        if let functionCall = self.functionCall {
            switch functionCall {
            case .auto:
                try container.encode("auto", forKey: .functionCall)

            case .none:
                break

            default:
                try container.encode(self.functionCall, forKey: .functionCall)
            }
        }
    }
}
