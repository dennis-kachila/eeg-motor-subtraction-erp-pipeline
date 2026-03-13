function Id = GetLastFileIndex(oldfiles)

    myFiles = vertcat(oldfiles{:});
    Id = max(str2num(myFiles(:,end-6:end-4)));

end