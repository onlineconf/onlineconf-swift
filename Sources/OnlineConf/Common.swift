
import CCKV

public enum ConfigError : Error {
        case failedConvert
}

public enum CKVType : RawRepresentable, Equatable {
        case text_noformat
        case text_format
        case cdb_noformat
        case cdb_format

        case custom(UInt32)

        public init(rawValue : UInt32) {
                switch ckv_kind(rawValue) {
                        case CKV_TEXT_NOFORMAT: self = .text_noformat
                        case CKV_TEXT_WITH_FORMAT: self = .text_format
                        case CKV_CDB_NOFORMAT: self = .cdb_noformat
                        case CKV_CDB_BYTEFORMAT: self = .cdb_format
                        default: self = .custom(rawValue)
                }
        }

        public var rawValue : UInt32 {
                let type : ckv_kind
                switch self {
                        case .text_noformat: type = CKV_TEXT_NOFORMAT
                        case .text_format: type = CKV_TEXT_WITH_FORMAT
                        case .cdb_noformat: type = CKV_CDB_NOFORMAT
                        case .cdb_format: type = CKV_CDB_BYTEFORMAT
                        case .custom(let rawValue): type = ckv_kind(rawValue : rawValue)
                }
                return type.rawValue
        }
}

public enum CKVMemory : RawRepresentable, Equatable {
        case mmap_malloc
        case mmap
        case malloc

        case custom(UInt32)

        public init(rawValue : UInt32) {
                switch ckv_try_mmap(rawValue) {
                        case CKV_MMAP_MALLOC_ON_FAIL: self = .mmap_malloc
                        case CKV_MMAP_OR_FAIL: self = .mmap
                        case CKV_MALLOC_ONLY: self = .malloc
                        default: self = .custom(rawValue)
                }
        }

        public var rawValue : UInt32 {
                let type : ckv_try_mmap
                switch self {
                        case .mmap_malloc: type = CKV_MMAP_MALLOC_ON_FAIL
                        case .mmap: type = CKV_MMAP_OR_FAIL
                        case .malloc: type = CKV_MALLOC_ONLY
                        case .custom(let rawValue): type = ckv_try_mmap(rawValue : rawValue)
                }
                return type.rawValue
        }
}
