
import CCKV

public class Config {
        private var kv : OpaquePointer?
        init(path: String, kind: CKVType, memory: CKVMemory, ecb: @escaping ckv_error_cb, ecbarg: UnsafeMutableRawPointer?) {
                kv = ckv_open(path, ckv_kind(kind.rawValue), ckv_try_mmap(memory.rawValue), ecb, ecbarg)
        }

        deinit {
                ckv_close(kv)
        }

        public func getParam(key : String) -> String? {
                let param = get(key : key)
                guard let vf = param else { return nil }
                return vf.0
        }

        public func getParam(key: String) -> Int? {
                let param = get(key: key)
                guard let vf = param else { return nil }
                return Int(vf.0)
        }

        public func getParam(key: String) -> Bool {
                let param = get(key: key)
                guard let vf = param else { return false }
                if vf.0.isEmpty || vf.0 == "0" { return false }
                print (vf.0)
                return true
        }

        private func get(key : String) -> (String, String?)? {
                var v : ckv_str = ckv_str()
                var f : ckv_str = ckv_str()
                ckv_key_get(kv, key, Int32(key.characters.count), &v, &f)

                let v_len = Int(v.len)
                guard let c_v = v.str else { return nil }
                guard let value = c_v.withMemoryRebound(to: UTF8.CodeUnit.self, capacity : v_len, {
                        String._fromCodeUnitSequence(UTF8.self, input : UnsafeBufferPointer(start : $0, count : v_len))
                })
                else { return nil }

                let f_len = Int(f.len)
                guard let c_f = f.str else { return (value, nil) }
                guard let format = c_f.withMemoryRebound(to: UTF8.CodeUnit.self, capacity : f_len, {
                        String._fromCodeUnitSequence(UTF8.self, input : UnsafeBufferPointer(start : $0, count : f_len))
                })
                else { return (value, nil) }
                return (value, format)
        }
}

