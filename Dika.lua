Buatkan script Lua untuk game bergaya Growtopia dengan spesifikasi berikut.

Variabel di bagian atas:
- id = 2488 (ID item)
- count = 200 (jumlah item)

Fungsi:
1. Find() mengirim paket beli dengan SendPacket(2, ...). Isinya, tiap baris dipisah newline:
   action|dialog_return
   dialog_name|nupirkti
   name|Roulette Wheel
   pirkti_id|<id>
   count|<count>

2. Drop() mengirim paket drop dengan SendPacket(2, ...). Isinya:
   action|dialog_return
   dialog_name|drop_item
   itemID|<id>
   count|<count>

Alur utama:
- Jalankan loop tanpa henti (while true do).
- Di tiap putaran: panggil Drop(), sleep(300), panggil Find(), sleep(300).

Aturan kode:
- Gunakan [[ ]] atau "\n" supaya setiap pasangan key|value berada di baris terpisah.
- Sambung variabel id dan count ke string dengan operator "..".
- Beri komentar singkat di setiap fungsi.
- Beri hanya kode Lua yang siap pakai, tanpa penjelasan panjang.
