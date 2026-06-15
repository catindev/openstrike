extends RefCounted

class_name OpenStrikeBspBinaryReader

var _bytes := PackedByteArray()


func setup(bytes: PackedByteArray) -> void:
	_bytes = bytes


func size() -> int:
	return _bytes.size()


func can_read(offset: int, length: int) -> bool:
	return offset >= 0 and length >= 0 and offset + length <= _bytes.size()


func read_i32(offset: int) -> int:
	if not can_read(offset, 4):
		return 0
	return int(_bytes.decode_s32(offset))


func read_i16(offset: int) -> int:
	if not can_read(offset, 2):
		return 0
	return int(_bytes.decode_s16(offset))


func read_f32(offset: int) -> float:
	if not can_read(offset, 4):
		return 0.0
	return float(_bytes.decode_float(offset))


func read_slice(offset: int, length: int) -> PackedByteArray:
	if not can_read(offset, length):
		return PackedByteArray()
	return _bytes.slice(offset, offset + length)
