// Who the browser is signed in as. The story switches this, the player does not.
module.exports = {
  DEFAULT: 'peter',
  PROFILES: {
    peter: { name: 'Peter Adam', email: 'peter.adam@gaaglu.com', initial: 'P', color: '#2F6FED', theme: 'normal',
      thoughts: {
        mild: ['Không có thông tin gì hữu ích.', 'Có vẻ không phải trang cần tìm.', 'Chẳng liên quan gì cả.', 'Không phải cái mình đang tìm.'],
        annoyed: ['Sao toàn mấy thứ vớ vẩn thế này?', 'Mình đang đọc cái quái gì vậy?', 'Đủ rồi, trang này chẳng giúp được gì.', 'Không có thời gian cho mấy thứ này đâu.'],
        done: ['Chậc, phí cả thời gian!', 'Mẹ kiếp, toàn rác!', 'Thôi dẹp! Bực cả mình.', 'Trang gì mà vô dụng thế không biết!'],
        refused: ['Thôi, không điền gì lên đây đâu.', 'Không, mình chẳng gửi gì cho trang này cả.'],
        failed: ['Trang này không vào được.', 'Không tải nổi. Thử trang khác vậy.'],
      } },
  },
};
