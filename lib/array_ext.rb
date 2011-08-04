Array.class_eval do
  # разбиваем по пара что б получить ["00","01","02","2a"....]
  def to16pairs
    a=[]
    32.times {|i| a << ( self[i].to_s + self[i+1].to_s ) if i%2 == 0 }
    a
  end
end
